// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build esx

package runtime

import "unsafe"

// Continuation of the (assembly) sigtramp() logic.
// This may be called with the world stopped.
//go:nosplit
//go:nowritebarrierrec
func sigtrampgo(sig uint32, info *siginfo, ctx unsafe.Pointer) {
	if sigfwdgo(sig, info, ctx) {
		return
	}
	g := getg()
	if g == nil {
		badsignal(uintptr(sig), &sigctxt{info, ctx})
		return
	}

	setg(g.m.gsignal)
	sighandler(sig, info, ctx, g)
	setg(g)
}
