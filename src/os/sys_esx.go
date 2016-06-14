// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Linux-specific

package os

import (
	"strings"
	"syscall"
	"unsafe"
)

func hostname() (name string, err error) {
	var un syscall.Utsname
	err = syscall.Uname(&un)
	if err != nil {
		return "", err
	}

	// string from a slice of byte array
	nodename := string((*(*[65]byte)(unsafe.Pointer(&un.Nodename)))[:])
	end := strings.Index(nodename, "\x00")
	name = nodename[:end]
	return name, err
}
