// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.subsystem.manager;

import trinove.subsystem.subsystem;
import trinove.log;
import std.exception : enforce;
import std.algorithm : remove, filter, canFind;
import std.array : array;
import std.stdio : writeln, writefln;

// Subsystem registration, dependency resolution, and lifecycle.
struct SubsystemManager
{
	@disable this();

	private static __gshared
	{
		ISubsystem[string] _subsystems;
		ISubsystem[ServiceName] _serviceProviders;
		ISubsystem[] _initOrder;
		bool[string] _initialized;
	}

	static void register(ISubsystem subsystem)
	{
		enforce(subsystem !is null, "Cannot register null subsystem");
		enforce(subsystem.name !in _subsystems, "Subsystem already registered: " ~ subsystem.name);

		_subsystems[subsystem.name] = subsystem;

		// Register services this subsystem provides
		ServiceName[] provided;
		subsystem.getProvidedServices(provided);
		foreach (svc; provided)
		{
			if (svc in _serviceProviders)
			{
				auto existing = _serviceProviders[svc];
				writefln!"Warning: Service '%s' provided by multiple subsystems: %s and %s"(svc.toString(), existing.name,
						subsystem.name);
			}
			else
			{
				_serviceProviders[svc] = subsystem;
			}
		}
	}

	// Get by name
	static ISubsystem get(string name)
	{
		auto ptr = name in _subsystems;
		return ptr ? *ptr : null;
	}

	// Get by provided service
	static ISubsystem getByService(ServiceName service)
	{
		auto ptr = service in _serviceProviders;
		return ptr ? *ptr : null;
	}

	// Get a typed subsystem by provided service
	static T getByService(T)(ServiceName service)
	{
		return cast(T) getByService(service);
	}

	static void initializeAll()
	{
		checkIncompatibilities();
		auto order = resolveDependencies();

		foreach (subsystem; order)
		{
			subsystem.initialize();
			_initOrder ~= subsystem;
			_initialized[subsystem.name] = true;
		}

		debug logDebug("All subsystems initialized");
	}

	static void shutdownAll()
	{
		foreach_reverse (subsystem; _initOrder)
		{
			subsystem.shutdown();
		}

		_initOrder.length = 0;
		_initialized.clear();

		debug logDebug("All subsystems shut down");
	}

	static void reset()
	{
		shutdownAll();
		_subsystems.clear();
		_serviceProviders.clear();
	}

	private static void checkIncompatibilities()
	{
		foreach (subsystem; _subsystems)
		{
			ServiceName[] incompatible;
			subsystem.getIncompatibleServices(incompatible);

			foreach (svc; incompatible)
			{
				if (svc in _serviceProviders)
				{
					auto provider = _serviceProviders[svc];
					if (provider !is subsystem)
					{
						throw new Exception(
								"Subsystem '" ~ subsystem.name ~ "' is incompatible with service '" ~ svc.toString()
								~ "' provided by '" ~ provider.name ~ "'");
					}
				}
			}
		}
	}

	private static ISubsystem[] resolveDependencies()
	{
		ISubsystem[] result;
		bool[string] visited;
		bool[string] visiting; // For cycle detection

		void visit(ISubsystem subsystem)
		{
			if (subsystem.name in visited)
				return;

			if (subsystem.name in visiting)
				throw new Exception("Circular dependency detected: " ~ subsystem.name);

			visiting[subsystem.name] = true;

			ServiceName[] required;
			subsystem.getRequiredServices(required);

			foreach (svc; required)
			{
				auto ptr = svc in _serviceProviders;
				if (ptr is null)
				{
					throw new Exception("Subsystem '" ~ subsystem.name ~ "' requires service '" ~ svc.toString()
							~ "' which is not provided by any registered subsystem");
				}

				auto provider = *ptr;
				if (provider.name !in _initialized)
					visit(provider);
			}

			visiting.remove(subsystem.name);
			visited[subsystem.name] = true;

			if (subsystem.name !in _initialized)
				result ~= subsystem;
		}

		foreach (subsystem; _subsystems)
			visit(subsystem);

		return result;
	}
}
