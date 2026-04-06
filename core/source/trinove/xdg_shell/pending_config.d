// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.xdg_shell.pending_config;

import std.typecons : Nullable;

// Generic pending configuration queue with serial tracking.
// Manages the configure → ack → commit lifecycle for xdg roles.
//
// When the client acks serial N, all entries from the oldest up to and including N
// are consumed (per spec). The stored acked data is taken as-is from the matched entry.
struct PendingConfigQueue(Data)
{
	private struct Entry
	{
		uint serial;
		Data data;
	}

	private enum Capacity = 48;
	private Entry[Capacity] _buffer;
	private size_t _head = 0;
	private size_t _count = 0;
	private Nullable!Entry _acked;

	// Add a new pending config after sending configure.
	// The serial should be the one from xdg_surface.configure.
	void add(uint serial, Data data)
	{
		if (_count >= Capacity)
		{
			// Queue full, drop the oldest.
			_head = (_head + 1) % Capacity;
			_count--;
		}
		const idx = (_head + _count) % Capacity;
		_buffer[idx] = Entry(serial, data);
		_count++;
	}

	// Called when client acks a serial.
	//
	// Consumes all entries from the oldest up to and including the matched serial.
	// Entries sent AFTER the acked serial remain pending.
	// The stored acked data is the matched entry's data taken as-is.
	void ack(uint serial)
	{
		foreach (i; 0 .. _count)
		{
			const idx = (_head + i) % Capacity;
			if (_buffer[idx].serial == serial)
			{
				_acked = Entry(serial, _buffer[idx].data);
				_head = (_head + i + 1) % Capacity;
				_count -= (i + 1);
				return;
			}
		}
	}

	bool hasAcked() const
	{
		return !_acked.isNull;
	}

	// Get the acked serial (check hasAcked first)
	uint getAckedSerial() const
	{
		return _acked.get.serial;
	}

	// Get the acked data (check hasAcked first)
	ref const(Data) getAckedData() const
	{
		return _acked.get.data;
	}

	void clearAcked()
	{
		_acked.nullify();
	}

	bool hasPending() const
	{
		return _count > 0;
	}

	size_t pendingCount() const
	{
		return _count;
	}

	// Peek at the most recently queued pending config data without consuming it.
	// Returns true and fills `data` if a pending entry exists, false if queue is empty.
	bool peekLastData(out Data data)
	{
		if (_count == 0)
			return false;
		const idx = (_head + _count - 1) % Capacity;
		data = _buffer[idx].data;
		return true;
	}

	// Discard all pending (un-acked) entries without applying them.
	void discardPending()
	{
		_head = 0;
		_count = 0;
	}

	// Fold all entries from oldest up to and including `serial` (in order)
	// by calling `fn` for each, then consume those entries.
	// Returns true if the serial was found.
	//
	// Use this instead of separate foreachToSerial + ack when you need to
	// accumulate delta data across multiple pending entries in a single pass.
	bool foldAndAck(uint serial, scope void delegate(ref const Data) fn)
	{
		foreach (i; 0 .. _count)
		{
			const idx = (_head + i) % Capacity;
			fn(_buffer[idx].data);
			if (_buffer[idx].serial == serial)
			{
				_acked = Entry(serial, _buffer[idx].data);
				_head = (_head + i + 1) % Capacity;
				_count -= (i + 1);
				return true;
			}
		}
		return false;
	}
}

unittest
{
	struct TestData
	{
		int value;
		string name;
	}

	PendingConfigQueue!TestData queue;

	// Initially empty
	assert(!queue.hasAcked());
	assert(!queue.hasPending());

	// Add some pending configs
	queue.add(1, TestData(100, "first"));
	queue.add(2, TestData(200, "second"));
	queue.add(3, TestData(300, "third"));

	assert(queue.hasPending());
	assert(queue.pendingCount() == 3);
	assert(!queue.hasAcked());

	// Ack the second one - should discard first, keep third
	queue.ack(2);

	assert(queue.hasAcked());
	assert(queue.getAckedSerial() == 2);
	assert(queue.getAckedData().value == 200);
	assert(queue.getAckedData().name == "second");
	assert(queue.pendingCount() == 1); // only third remains

	// Clear after applying
	queue.clearAcked();
	assert(!queue.hasAcked());

	// Ack unknown serial - no effect
	queue.ack(999);
	assert(!queue.hasAcked());

	// Ack the third
	queue.ack(3);
	assert(queue.hasAcked());
	assert(queue.getAckedData().value == 300);
	assert(queue.pendingCount() == 0);
}

// Test: Client skips to latest configure (skipping earlier ones)
unittest
{
	struct TestData
	{
		int value;
	}

	PendingConfigQueue!TestData queue;

	queue.add(10, TestData(100));
	queue.add(11, TestData(110));
	queue.add(12, TestData(120));
	queue.add(13, TestData(130));
	queue.add(14, TestData(140));

	assert(queue.pendingCount() == 5);

	// Client skips directly to latest, all earlier configs discarded
	queue.ack(14);

	assert(queue.hasAcked());
	assert(queue.getAckedSerial() == 14);
	assert(queue.getAckedData().value == 140);
	assert(queue.pendingCount() == 0);

	queue.clearAcked();

	queue.add(20, TestData(200));
	queue.add(21, TestData(210));
	queue.add(22, TestData(220));

	queue.ack(21);
	assert(queue.getAckedData().value == 210);
	assert(queue.pendingCount() == 1);

	queue.clearAcked();
	queue.ack(22);
	assert(queue.getAckedData().value == 220);
	assert(queue.pendingCount() == 0);
}

// Test: Multiple acks without clearing (client acks faster than commits)
unittest
{
	struct TestData
	{
		int value;
	}

	PendingConfigQueue!TestData queue;

	queue.add(1, TestData(10));
	queue.add(2, TestData(20));

	queue.ack(1);
	assert(queue.hasAcked());
	assert(queue.getAckedData().value == 10);

	// Before commit, client acks serial 2, overwrites acked
	queue.ack(2);
	assert(queue.hasAcked());
	assert(queue.getAckedData().value == 20);
	assert(queue.pendingCount() == 0);
}

// Test: Ring buffer wraps around correctly
unittest
{
	struct TestData
	{
		int value;
	}

	PendingConfigQueue!TestData queue;

	foreach (batch; 0 .. 5)
	{
		foreach (i; 0 .. 20)
		{
			const serial = cast(uint)(batch * 20 + i + 1);
			queue.add(serial, TestData(serial * 10));
		}

		const lastSerial = cast(uint)(batch * 20 + 20);
		queue.ack(lastSerial);

		assert(queue.hasAcked());
		assert(queue.getAckedSerial() == lastSerial);
		assert(queue.getAckedData().value == lastSerial * 10);
		assert(queue.pendingCount() == 0);
		queue.clearAcked();
	}
}

// Test: Overflow drops oldest entries
unittest
{
	struct TestData
	{
		int value;
	}

	PendingConfigQueue!TestData queue;
	enum cap = queue.Capacity;

	foreach (i; 0 .. cap)
		queue.add(cast(uint)(i + 1), TestData((i + 1) * 10));

	assert(queue.pendingCount() == cap);

	// Adding one more should drop oldest (serial 1)
	queue.add(cap + 1, TestData((cap + 1) * 10));
	assert(queue.pendingCount() == cap);

	queue.ack(1);
	assert(!queue.hasAcked());

	queue.ack(2);
	assert(queue.hasAcked());
	assert(queue.getAckedData().value == 20);

	queue.clearAcked();

	queue.ack(cap + 1);
	assert(queue.hasAcked());
	assert(queue.getAckedData().value == (cap + 1) * 10);
}
