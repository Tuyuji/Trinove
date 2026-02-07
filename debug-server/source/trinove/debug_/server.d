// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.debug_.server;

import std.socket;
import std.string : split, startsWith, indexOf, replace;
import std.algorithm : filter, sort;
import std.array : array;
import std.format : format;
import core.thread;
import core.time : msecs;

import trinove.log;

// Compile-time embedded resources
private immutable string indexHtml = import("debug/index.html");
private immutable string styleCss = import("debug/style.css");

// Handler delegate for a registered view route.
alias ViewHandler = string delegate(string path);

// A registered route entry in the debug HTTP server.
private struct ViewRoute
{
	string path; // exact path, or prefix if isPrefix == true
	bool isPrefix;
	string contentType; // e.g. "text/html", "text/plain"
	string canonicalView; // nav tab that owns this route (used for shell wrapping)
	ViewHandler handler;
}

// Minimal HTTP server for inspecting compositor state at runtime.
// All view logic lives outside this class; subsystems register handlers
// via registerView / registerPrefixView before calling start().
class DebugServer
{
	private
	{
		ushort _port;
		bool _running;
		Socket _listenSocket;
		Thread _serverThread;
		EventSourceClient[] _eventClients;
		Object _clientsMutex;
		ViewRoute[] _routes;
	}

	this(ushort port = 8080)
	{
		_port = port;
		_clientsMutex = new Object();
	}

	// Register a handler for an exact path.
	// canonicalView is set to path (identifies which nav tab owns this route).
	void registerView(string path, ViewHandler handler, string contentType = "text/html")
	{
		insertRoute(ViewRoute(path, false, contentType, path, handler));
	}

	// ditto — explicit canonicalView for action endpoints that belong to another tab.
	void registerView(string path, string canonicalView, ViewHandler handler, string contentType = "text/html")
	{
		insertRoute(ViewRoute(path, false, contentType, canonicalView, handler));
	}

	// Register a handler for all paths sharing a given prefix.
	void registerPrefixView(string prefix, string canonicalView, ViewHandler handler, string contentType = "text/html")
	{
		insertRoute(ViewRoute(prefix, true, contentType, canonicalView, handler));
	}

	// Insert a route and keep the table sorted: exact routes before prefix routes,
	// longer paths before shorter within each group.
	private void insertRoute(ViewRoute route)
	{
		_routes ~= route;
		_routes.sort!((a, b) {
			if (a.isPrefix != b.isPrefix)
				return !a.isPrefix; // exact (false) sorts before prefix (true)
			return a.path.length > b.path.length; // longer path wins ties
		});
	}

	void start()
	{
		logInfo("Starting debug server on port %s", _port);
		_serverThread = new Thread(&serverLoop);
		_serverThread.start();
	}

	void stop()
	{
		_running = false;

		synchronized (_clientsMutex)
		{
			foreach (client; _eventClients)
				client.close();
			_eventClients = [];
		}

		if (_listenSocket !is null)
			_listenSocket.close();

		if (_serverThread !is null)
			_serverThread.join();

		logInfo("Debug server stopped");
	}

	// Broadcast an SSE event to all connected clients.
	void broadcastEvent(string eventType, string data)
	{
		synchronized (_clientsMutex)
		{
			_eventClients = _eventClients.filter!(c => c.isActive).array;
			foreach (client; _eventClients)
				client.sendEvent(eventType, data);
		}
	}

	private void serverLoop()
	{
		try
		{
			_listenSocket = new TcpSocket();
			_listenSocket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
			_listenSocket.bind(new InternetAddress("127.0.0.1", _port));
			_listenSocket.listen(10);
			_listenSocket.blocking = false;
			_running = true;

			logInfo("Debug server listening on http://127.0.0.1:%s", _port);

			auto socketSet = new SocketSet();

			while (_running)
			{
				socketSet.reset();
				socketSet.add(_listenSocket);

				auto ready = Socket.select(socketSet, null, null, 100.msecs);

				if (ready > 0 && _running && socketSet.isSet(_listenSocket))
				{
					try
					{
						Socket clientSocket = _listenSocket.accept();
						if (clientSocket !is null)
						{
							auto thread = new Thread(() => handleRequest(clientSocket));
							thread.start();
						}
					}
					catch (Exception e)
					{
						if (_running)
							logWarn("Error accepting connection: %s", e.msg);
					}
				}
			}
		}
		catch (Exception e)
		{
			if (_running)
				logError("Debug server error: %s", e.msg);
		}
	}

	private void handleRequest(Socket socket)
	{
		try
		{
			char[4096] buffer;
			ptrdiff_t received = socket.receive(buffer);

			if (received <= 0)
			{
				socket.close();
				return;
			}

			string request = cast(string) buffer[0 .. received];
			auto lines = request.split("\r\n");
			if (lines.length == 0)
			{
				socket.close();
				return;
			}

			auto requestLine = lines[0].split(" ");
			if (requestLine.length < 3)
			{
				sendError(socket, 400, "Bad Request");
				return;
			}

			string path = requestLine[1];

			auto qIdx = path.indexOf('?');
			if (qIdx != -1)
				path = path[0 .. qIdx];

			// Static files
			if (path == "/style.css")
			{
				sendResponse(socket, 200, "OK", "text/css", styleCss);
				return;
			}

			if (path == "/" || path == "/index.html")
			{
				sendShell(socket, "/view/overview");
				return;
			}

			if (path == "/events")
			{
				handleEventSource(socket);
				return;
			}

			// Dynamic view routes — dispatched through the registered route table
			bool htmx = isHtmxRequest(lines);

			foreach (ref route; _routes)
			{
				bool matches = route.isPrefix ? path.startsWith(route.path) : path == route.path;
				if (!matches)
					continue;

				if (!htmx && route.contentType == "text/html")
				{
					sendShell(socket, route.canonicalView);
					return;
				}
				sendResponse(socket, 200, "OK", route.contentType, route.handler(path));
				return;
			}

			sendError(socket, 404, "Not Found");
		}
		catch (Throwable e)
		{
			logWarn("Request error: %s", e.msg);
			try
			{
				sendError(socket, 500, "Internal Server Error");
			}
			catch (Exception)
			{
			}
		}
	}

	// Returns true if the request headers contain the HTMX request marker.
	private static bool isHtmxRequest(string[] lines)
	{
		foreach (line; lines)
		{
			if (line.startsWith("HX-Request:"))
				return true;
		}
		return false;
	}

	// Serve the full shell page with %%INITIAL_VIEW%% replaced by the canonical view path.
	private void sendShell(Socket socket, string initialView)
	{
		string html = indexHtml.replace("%%INITIAL_VIEW%%", initialView);
		sendResponse(socket, 200, "OK", "text/html", html);
	}

	private void handleEventSource(Socket socket)
	{
		string response = "HTTP/1.1 200 OK\r\n" ~ "Content-Type: text/event-stream\r\n" ~ "Cache-Control: no-cache\r\n"
			~ "Connection: keep-alive\r\n" ~ "\r\n";

		socket.send(response);
		socket.send(": connected\n\n");

		auto client = new EventSourceClient(socket);

		synchronized (_clientsMutex)
		{
			_eventClients ~= client;
		}

		client.sendEvent("status", `<span class="status connected">Connected</span>`);
	}

	private void sendResponse(Socket socket, int code, string status, string contentType, string body_)
	{
		string response = format("HTTP/1.1 %d %s\r\n" ~ "Content-Type: %s; charset=utf-8\r\n" ~ "Content-Length: %d\r\n"
				~ "Connection: close\r\n" ~ "\r\n", code, status, contentType, body_.length);

		socket.send(response);
		if (body_.length > 0)
			socket.send(body_);
		socket.close();
	}

	private void sendError(Socket socket, int code, string message)
	{
		sendResponse(socket, code, message, "text/plain", message);
	}
}

private class EventSourceClient
{
	private Socket _socket;
	private bool _active = true;

	this(Socket socket)
	{
		_socket = socket;
	}

	bool isActive() const
	{
		return _active;
	}

	void sendEvent(string eventType, string data)
	{
		if (!_active)
			return;

		try
		{
			import std.array : appender;

			auto msg = appender!string;
			msg ~= "event: ";
			msg ~= eventType;
			msg ~= "\n";

			foreach (line; data.split("\n"))
			{
				msg ~= "data: ";
				msg ~= line;
				msg ~= "\n";
			}
			msg ~= "\n";

			_socket.send(msg[]);
		}
		catch (Exception)
		{
			_active = false;
		}
	}

	void close()
	{
		_active = false;
		try
		{
			_socket.close();
		}
		catch (Exception)
		{
		}
	}
}
