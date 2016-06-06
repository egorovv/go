// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//
// System calls and other sys.stuff for AMD64, Linux
//

#include "go_asm.h"
#include "go_tls.h"
#include "textflag.h"

TEXT runtime·exit(SB),NOSPLIT,$0-4
	MOVL	code+0(FP), DI
	MOVL	$231, AX	// exitgroup - force all os threads to exit
	SYSCALL
	RET

TEXT runtime·exit1(SB),NOSPLIT,$0-4
	MOVL	code+0(FP), DI
	MOVL	$60, AX	// exit - exit the current os thread
	SYSCALL
	RET

TEXT runtime·open(SB),NOSPLIT,$0-20
	MOVQ	name+0(FP), DI
	MOVL	mode+8(FP), SI
	MOVL	perm+12(FP), DX
	MOVL	$2, AX			// syscall entry
	SYSCALL
	CMPQ	AX, $0xfffffffffffff001
	JLS	2(PC)
	MOVL	$-1, AX
	MOVL	AX, ret+16(FP)
	RET

TEXT runtime·closefd(SB),NOSPLIT,$0-12
	MOVL	fd+0(FP), DI
	MOVL	$3, AX			// syscall entry
	SYSCALL
	CMPQ	AX, $0xfffffffffffff001
	JLS	2(PC)
	MOVL	$-1, AX
	MOVL	AX, ret+8(FP)
	RET

TEXT runtime·write(SB),NOSPLIT,$0-28
	MOVQ	fd+0(FP), DI
	MOVQ	p+8(FP), SI
	MOVL	n+16(FP), DX
	MOVL	$1, AX			// syscall entry
	SYSCALL
	CMPQ	AX, $0xfffffffffffff001
	JLS	2(PC)
	MOVL	$-1, AX
	MOVL	AX, ret+24(FP)
	RET

TEXT runtime·read(SB),NOSPLIT,$0-28
	MOVL	fd+0(FP), DI
	MOVQ	p+8(FP), SI
	MOVL	n+16(FP), DX
	MOVL	$0, AX			// syscall entry
	SYSCALL
	CMPQ	AX, $0xfffffffffffff001
	JLS	2(PC)
	MOVL	$-1, AX
	MOVL	AX, ret+24(FP)
	RET

TEXT runtime·getrlimit(SB),NOSPLIT,$0-20
	MOVL	kind+0(FP), DI
	MOVQ	limit+8(FP), SI
	MOVL	$97, AX			// syscall entry
	SYSCALL
	MOVL	AX, ret+16(FP)
	RET

TEXT runtime·usleep(SB),NOSPLIT,$16
	MOVL	$0, DX
	MOVL	usec+0(FP), AX
	MOVL	$1000000, CX
	DIVL	CX
	MOVQ	AX, 0(SP)
	MOVQ	DX, 8(SP)

	// select(0, 0, 0, 0, &tv)
	MOVL	$0, DI
	MOVL	$0, SI
	MOVL	$0, DX
	MOVL	$0, R10
	MOVQ	SP, R8
	MOVL	$23, AX
	SYSCALL
	RET

TEXT runtime·gettid(SB),NOSPLIT,$0-4
	MOVL	$186, AX	// syscall - gettid
	SYSCALL
	MOVL	AX, ret+0(FP)
	RET

TEXT runtime·raise(SB),NOSPLIT,$0
	MOVL	$186, AX	// syscall - gettid
	SYSCALL
	MOVL	AX, DI	// arg 1 tid
	MOVL	sig+0(FP), SI	// arg 2
	MOVL	$200, AX	// syscall - tkill
	SYSCALL
	RET

TEXT runtime·raiseproc(SB),NOSPLIT,$0
	MOVL	$39, AX	// syscall - getpid
	SYSCALL
	MOVL	AX, DI	// arg 1 pid
	MOVL	sig+0(FP), SI	// arg 2
	MOVL	$62, AX	// syscall - kill
	SYSCALL
	RET

TEXT runtime·setitimer(SB),NOSPLIT,$0-24
	MOVL	mode+0(FP), DI
	MOVQ	new+8(FP), SI
	MOVQ	old+16(FP), DX
	MOVL	$38, AX			// syscall entry
	SYSCALL
	RET

TEXT runtime·mincore(SB),NOSPLIT,$0-28
	MOVQ	addr+0(FP), DI
	MOVQ	n+8(FP), SI
	MOVQ	dst+16(FP), DX
	MOVL	$27, AX			// syscall entry
	SYSCALL
	MOVL	AX, ret+24(FP)
	RET

// func now() (sec int64, nsec int32)
TEXT time·now(SB),NOSPLIT,$16
	LEAQ	0(SP), DI
	MOVQ	$0, SI
	MOVL	$96, AX
	SYSCALL
	MOVQ	0(SP), AX	// sec
	MOVL	8(SP), DX	// usec
	IMULQ	$1000, DX
	MOVQ	AX, sec+0(FP)
	MOVL	DX, nsec+8(FP)
	RET

TEXT runtime·nanotime(SB),NOSPLIT,$16
	LEAQ	0(SP), DI
	MOVQ	$0, SI
	MOVL	$96, AX
	SYSCALL
	MOVQ	0(SP), AX	// sec
	MOVL	8(SP), DX	// usec
	IMULQ	$1000, DX
	// sec is in AX, nsec in DX
	// return nsec in AX
	IMULQ	$1000000000, AX
	ADDQ	DX, AX
	MOVQ	AX, ret+0(FP)
	RET

TEXT runtime·rtsigprocmask(SB),NOSPLIT,$0-28
	MOVL	sig+0(FP), DI
	MOVQ	new+8(FP), SI
	MOVQ	old+16(FP), DX
	MOVL	size+24(FP), R10
	MOVL	$14, AX			// syscall entry
	SYSCALL
	CMPQ	AX, $0xfffffffffffff001
	JLS	2(PC)
	MOVL	$0xf1, 0xf1  // crash
	RET

TEXT runtime·rt_sigaction(SB),NOSPLIT,$0-36
	MOVQ	sig+0(FP), DI
	MOVQ	new+8(FP), SI
	MOVQ	old+16(FP), DX
	MOVQ	size+24(FP), R10
	MOVL	$13, AX			// syscall entry
	SYSCALL
	MOVL	AX, ret+32(FP)
	RET

TEXT runtime·sigfwd(SB),NOSPLIT,$0-32
	MOVL	sig+8(FP), DI
	MOVQ	info+16(FP), SI
	MOVQ	ctx+24(FP), DX
	MOVQ	fn+0(FP), AX
	CALL	AX
	RET

TEXT runtime·sigtramp(SB),NOSPLIT,$24
        MOVQ    -8(FS), AX //g
        MOVQ    g_m(AX), BX
        MOVQ    m_gsignal(BX), BX
        MOVQ    (g_stack+stack_hi)(BX), BX // g.m.gsignal.stack.hi
        SUBQ    $32, BX
	MOVQ	DI, 0(BX)   // signum
	MOVQ	SI, 8(BX)   // info
	MOVQ	DX, 16(BX)  // ctx
	MOVQ	SP, 24(BX)  // old stack
        MOVQ    BX, SP      // switch stack
        
	MOVQ	$runtime·sigtrampgo(SB), AX
	CALL AX
	MOVQ	24(SP), SP //restore stack
	RET

TEXT runtime·sigreturn(SB),NOSPLIT,$0
	MOVL	$15, AX	// rt_sigreturn
	SYSCALL
	INT $3	// not reached

TEXT runtime·sysMmap(SB),NOSPLIT,$0
	MOVQ	addr+0(FP), DI
	MOVQ	n+8(FP), SI
	MOVL	prot+16(FP), DX
	MOVL	flags+20(FP), R10
	MOVL	fd+24(FP), R8
	MOVL	off+28(FP), R9

	MOVL	$9, AX			// mmap
	SYSCALL
	CMPQ	AX, $0xfffffffffffff001
	JLS	3(PC)
	NOTQ	AX
	INCQ	AX
	MOVQ	AX, ret+32(FP)
	RET

// Call the function stored in _cgo_mmap using the GCC calling convention.
// This must be called on the system stack.
TEXT runtime·callCgoMmap(SB),NOSPLIT,$16
	MOVQ	addr+0(FP), DI
	MOVQ	n+8(FP), SI
	MOVL	prot+16(FP), DX
	MOVL	flags+20(FP), CX
	MOVL	fd+24(FP), R8
	MOVL	off+28(FP), R9
	MOVQ	_cgo_mmap(SB), AX
	MOVQ	SP, BX
	ANDQ	$~15, SP	// alignment as per amd64 psABI
	MOVQ	BX, 0(SP)
	CALL	AX
	MOVQ	0(SP), SP
	MOVQ	AX, ret+32(FP)
	RET

TEXT runtime·munmap(SB),NOSPLIT,$0
	MOVQ	addr+0(FP), DI
	MOVQ	n+8(FP), SI
	MOVQ	$11, AX	// munmap
	SYSCALL
	CMPQ	AX, $0xfffffffffffff001
	JLS	2(PC)
	MOVL	$0xf1, 0xf1  // crash
	RET

TEXT runtime·madvise(SB),NOSPLIT,$0
	MOVQ	addr+0(FP), DI
	MOVQ	n+8(FP), SI
	MOVL	flags+16(FP), DX
	MOVQ	$28, AX	// madvise
	SYSCALL
	// ignore failure - maybe pages are locked
	RET

// int64 futex(int32 *uaddr, int32 op, int32 val,
//	struct timespec *timeout, int32 *uaddr2, int32 val2);
TEXT runtime·futex(SB),NOSPLIT,$0
	MOVQ	addr+0(FP), DI
	MOVL	op+8(FP), SI
	MOVL	val+12(FP), DX
	MOVQ	ts+16(FP), R10
	MOVQ	addr2+24(FP), R8
	MOVL	val3+32(FP), R9
	MOVL	$202, AX
	SYSCALL
	MOVL	AX, ret+40(FP)
	RET

// int32 clone(int32 flags, void *stack, M *mp, G *gp, void (*fn)(void));
TEXT runtime·clone(SB),NOSPLIT,$0
        MOVQ    $0, DX
        MOVQ    $0, R10

        MOVL    flags+0(FP), DI
        MOVQ    stack+8(FP), SI
        MOVQ    mp+16(FP), R8
        MOVQ    gp+24(FP), R9
        MOVQ    fn+32(FP), R12

        MOVQ    R8, -24(SI)
        MOVQ    R9, -16(SI)
        MOVQ    R12, -8(SI)

        MOVL    $56, AX
        SYSCALL

        // In parent, return.
        CMPQ    AX, $0
        JEQ     3(PC)
        MOVL    AX, ret+40(FP)
        RET

       // In child, on new stack.
        MOVQ    -24(SP), R8
        MOVQ    -16(SP), R9
        MOVQ    -8(SP),  R12
        
	// If g or m are nil, skip Go-related setup.
	CMPQ	R8, $0    // m
	JEQ	nog
	CMPQ	R9, $0    // g
	JEQ	nog

	// Initialize m->procid to Linux tid
	MOVL	$186, AX	// gettid
	SYSCALL
	MOVQ	AX, m_procid(R8)

	// Set FS to point at m->tls.
	LEAQ	m_tls(R8), DI
	CALL	runtime·settls(SB)

	// In child, set up new stack
	get_tls(CX)
	MOVQ	R8, g_m(R9)
	MOVQ	R9, g(CX)
	CALL	runtime·stackcheck(SB)

nog:
	// Call fn
	CALL	R12

	// It shouldn't return. If it does, exit that thread.
	MOVL	$111, DI
	MOVL	$60, AX
	SYSCALL
	JMP	-3(PC)	// keep exiting

TEXT runtime·sigaltstack(SB),NOSPLIT,$-8
	MOVQ	new+8(SP), DI
	MOVQ	old+16(SP), SI
	MOVQ	$131, AX
	SYSCALL
	CMPQ	AX, $0xfffffffffffff001
	JLS	2(PC)
	MOVL	$0xf1, 0xf1  // crash
	RET

// set tls base to DI
TEXT runtime·settls(SB),NOSPLIT,$32
	ADDQ	$8, DI	// ELF wants to use -8(FS)
	MOVQ	DI, SI
	MOVQ	$0x1002, DI	// ARCH_SET_FS
	MOVQ	$158, AX	// arch_prctl
	SYSCALL
	CMPQ	AX, $0xfffffffffffff001
	JLS	2(PC)
	MOVL	$0xf1, 0xf1  // crash
	RET

TEXT runtime·osyield(SB),NOSPLIT,$0
	MOVL	$24, AX
	SYSCALL
	RET

TEXT runtime·sched_getaffinity(SB),NOSPLIT,$0
	MOVQ	pid+0(FP), DI
	MOVQ	len+8(FP), SI
	MOVQ	buf+16(FP), DX
	MOVL	$204, AX			// syscall entry
	SYSCALL
	MOVL	AX, ret+24(FP)
	RET

// int32 runtime·epollcreate(int32 size);
TEXT runtime·epollcreate(SB),NOSPLIT,$0
	MOVL    size+0(FP), DI
	MOVL    $213, AX                        // syscall entry
	SYSCALL
	MOVL	AX, ret+8(FP)
	RET

// int32 runtime·epollcreate1(int32 flags);
TEXT runtime·epollcreate1(SB),NOSPLIT,$0
	MOVL	flags+0(FP), DI
	MOVL	$291, AX			// syscall entry
	SYSCALL
	MOVL	AX, ret+8(FP)
	RET

// func epollctl(epfd, op, fd int32, ev *epollEvent) int
TEXT runtime·epollctl(SB),NOSPLIT,$0
	MOVL	epfd+0(FP), DI
	MOVL	op+4(FP), SI
	MOVL	fd+8(FP), DX
	MOVQ	ev+16(FP), R10
	MOVL	$233, AX			// syscall entry
	SYSCALL
	MOVL	AX, ret+24(FP)
	RET

// int32 runtime·epollwait(int32 epfd, EpollEvent *ev, int32 nev, int32 timeout);
TEXT runtime·epollwait(SB),NOSPLIT,$0
	MOVL	epfd+0(FP), DI
	MOVQ	ev+8(FP), SI
	MOVL	nev+16(FP), DX
	MOVL	timeout+20(FP), R10
	MOVL	$232, AX			// syscall entry
	SYSCALL
	MOVL	AX, ret+24(FP)
	RET

// void runtime·closeonexec(int32 fd);
TEXT runtime·closeonexec(SB),NOSPLIT,$0
	MOVL    fd+0(FP), DI  // fd
	MOVQ    $2, SI  // F_SETFD
	MOVQ    $1, DX  // FD_CLOEXEC
	MOVL	$72, AX  // fcntl
	SYSCALL
	RET


// int access(const char *name, int mode)
TEXT runtime·access(SB),NOSPLIT,$0
	MOVQ	name+0(FP), DI
	MOVL	mode+8(FP), SI
	MOVL	$21, AX  // syscall entry
	SYSCALL
	MOVL	AX, ret+16(FP)
	RET

// int connect(int fd, const struct sockaddr *addr, socklen_t addrlen)
TEXT runtime·connect(SB),NOSPLIT,$0-28
	MOVL	fd+0(FP), DI
	MOVQ	addr+8(FP), SI
	MOVL	addrlen+16(FP), DX
	MOVL	$42, AX  // syscall entry
	SYSCALL
	MOVL	AX, ret+24(FP)
	RET

// int socket(int domain, int type, int protocol)
TEXT runtime·socket(SB),NOSPLIT,$0-20
	MOVL	domain+0(FP), DI
	MOVL	type+4(FP), SI
	MOVL	protocol+8(FP), DX
	MOVL	$41, AX  // syscall entry
	SYSCALL
	MOVL	AX, ret+16(FP)
	RET
