// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.linux.memfd;

// Create an anonymous file backed by memory (Linux-only syscall).
// See: memfd_create(2), <linux/memfd.h>
extern (C) int memfd_create(const(char)* name, uint flags) @nogc nothrow;

enum MFD_CLOEXEC = 0x0001U; // Set close-on-exec on the returned fd.
enum MFD_ALLOW_SEALING = 0x0002U; // Allow sealing operations via F_ADD_SEALS.

// fcntl sealing constants (from <linux/fcntl.h>)
enum F_ADD_SEALS = 1033; // Add seals to the file (fcntl cmd).
enum F_SEAL_SHRINK = 0x0002; // Prevent shrinking the file.
enum F_SEAL_GROW = 0x0004; // Prevent growing the file.
enum F_SEAL_WRITE = 0x0008; // Prevent writes to the file.
