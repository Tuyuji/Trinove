// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.main_thread_queue;

import core.sync.mutex : Mutex;

alias MainThreadAction = void delegate();

private __gshared Mutex _mutex;
private __gshared MainThreadAction[] _queue;

shared static this()
{
	_mutex = new Mutex();
}

void dispatchToMainThread(MainThreadAction action)
{
	synchronized (_mutex)
		_queue ~= action;
}

void drainMainThreadQueue()
{
	if (_queue.length == 0)
		return;

	MainThreadAction[] pending;
	synchronized (_mutex)
	{
		pending = _queue;
		_queue = null;
	}

	foreach (action; pending)
		action();
}
