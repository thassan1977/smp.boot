;/*
; * =====================================================================================
; *
; *       Filename:  jump64.asm
; *
; *    Description:  mode switch from 32 bit real to 64 bit protected mode
; *
; *        Version:  1.0
; *        Created:  30.08.2011 10:35:51
; *       Revision:  none
; *       Compiler:  nasm
; *
; *         Author:  Georg Wassen (gw) (wassen@lfbs.rwth-aachen.de), 
; *        Company:  Lehrstuhl für Betriebssysteme (Chair for Operating Systems)
; *                  RWTH Aachen University
; *
; * Copyright (c) 2011, Georg Wassen, RWTH Aachen University
; * All rights reserved.
; *
; * Redistribution and use in source and binary forms, with or without
; * modification, are permitted provided that the following conditions are met:
; *    * Redistributions of source code must retain the above copyright
; *      notice, this list of conditions and the following disclaimer.
; *    * Redistributions in binary form must reproduce the above copyright
; *      notice, this list of conditions and the following disclaimer in the
; *      documentation and/or other materials provided with the distribution.
; *    * Neither the name of the University nor the names of its contributors
; *      may be used to endorse or promote products derived from this
; *      software without specific prior written permission.
; *
; * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
; * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
; * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; * DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
; * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
; * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
; * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
; * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
; * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
; * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
; *
; * =====================================================================================
; */


%include "config.inc"

GLOBAL Realm32

; this is entered in IA32e mode (32 bit compatibility mode)
[BITS 32]
Realm32:
    mov ax, 0x0F00+'2'
    mov [0xB8000], ax
    mov ax, 0x0F00+'0'
    mov [0xB8002], ax

    ; load GDT for the long mode
    lgdt [GDT64.Pointer]
    jmp GDT64.Code:Realm64      ; set code segment and enter 64-bit long mode
    
[BITS 64]

Realm64:
    cli
    ; set the data segments
    mov ax, GDT64.Data
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    ;;mov ss, ax        ; WARNING: everything crashes, when SS is loaded!!! VERY WRONG
	 
    					; Thair HASSAN  : (08/10/2019)
						; code works fine without setting ss in QEMU
						; but on real hardware it crashes and gives #GPF on every interrupt
						; -----------------------------------------------------------------
    mov bx, 0			; also long mode ignores most segment registers 
    mov ss, bx			; but not SS and CS it's very crucial to set SS=0
						; never leave SS points to null descriptor
						; otherwise you would get General protection fault #GPF
						; on any interrupt exactly on IRETQ operation
						; a very hard lesson learned :(
						; AMD64 Architecture Programmer’s Manual Volume 2 : System Programming (chapter 8)

    ;mov rsp, Realm32            ; all below is no more needed...
                                ; (except multiboot_info_t, but the stack will not grow that fast...)
    ; Realm32 is 0x140000 (0x40000 above 1MB).
    ; Attention: below 1MB is I/O space (no RAM)

    extern stack            ; stack_t stack[MAX_CPUS] (in smp.c / smp.h)
    mov rdi, STACK_FRAMES*4096  ; stack size
    add rdi, stack          ; add offset of first stack
    mov rsp, rdi            ; set Stack Pointer


    mov ax, 0x0F00+'3'
    mov [0xB8000], ax
    mov ax, 0x0F00+'0'
    mov [0xB8002], ax

    
EXTERN main_bsp
    call main_bsp    ; main()
    ; in case, main() should ever return
endless:
    hlt
    jmp endless

; GDT for 64 bit long mode

align 64
GDT64:
    .Null: equ $ - GDT64        ; the null descriptor
    dw 0                        ; Limit (low)
    dw 0                        ; Base (low)
    db 0                        ; Base (middle)
    db 0                        ; Access
    db 0                        ; Granularity
    db 0                        ; Base (high)
    ; TODO : aren't the 64-bit GDT entries 16 Bytes long?!
    .Code : equ $ - GDT64
    dw 0                        ; Limit (low)
    dw 0                        ; Base (low)
    db 0                         ; Base (middle)
    db 10011000b                 ; Access.       p=1  dpl=00  11  c=0  r=0  a=0  (code segment)
    db 00100000b                 ; Granularity.  g=0  d=0  l=1  avl=0  seg.limit=0000    (l=1 -> 64 bit mode)
    db 0                         ; Base (high).
    .Data: equ $ - GDT64         ; The data descriptor.
    dw 0                         ; Limit (low).
    dw 0                         ; Base (low).
    db 0                         ; Base (middle)
    db 10010010b                 ; Access.       p=1  dpl=00  10  e=0  w=1  a=0  (data segment)
                                 ; 14.9.2011, Robert Uhl: w=1 to avoid #GP after interrupt handler
    db 00000000b                 ; Granularity.  g=0  d/b=0  0  avl=0  seg.limit=0000
    db 0                         ; Base (high).
    .Pointer:                    ; The GDT-pointer.
    dw $ - GDT64 - 1             ; Limit.
    dq GDT64                     ; Base.

global GDT_Code
GDT_Code : equ GDT64.Code

; In just a few pages in this tutorial, we will add our Interrupt
; Service Routines (ISRs) right here!

global idt_load
extern idtp
idt_load:
    lidt [idtp]
    ret

; define two multiline macros for interrupt stubs
; one with pushing a dummy error code,
; the other without (because these exceptions push an error code themselves)
%macro ISR_EXCEPTION_WITHOUT_ERRCODE 1
    global isr %+ %1
    isr %+ %1 :
        push rax
        mov ax, 0x0F00+'X'
        mov [0xB8000], ax
        mov ax, 0x0F00+'0' ;('0'+%1/10)
        mov [0xB8002], ax
        ;mov ax, 0x0F00+('0'+%1 % 10)
        ;mov [0xB8004], ax
        pop rax

    .endless:
        ;hlt
        ;jmp .endless

        push QWORD 0
        push QWORD %1
        jmp isr_common_stub
%endmacro

%macro ISR_EXCEPTION_WITH_ERRCODE 1
    global isr %+ %1
    isr %+ %1 :
        ; Errcode is already on the stack
        push QWORD %1
        jmp isr_common_stub
%endmacro

%macro ISR_INTERRUPT 1
    global isr %+ %1
    isr %+ %1 :
       ; push rax
       ; mov ax, 0x0F00+'I'
       ; mov [0xB8000], ax
       ; mov ax, 0x0F00+'0' ;('0'+%1/10)
       ; mov [0xB8002], ax
       ; ;mov ax, 0x0F00+('0'+%1 % 10)
       ; ;mov [0xB8004], ax
       ; pop rax

        push QWORD 0
        push QWORD %1
        jmp isr_common_stub
%endmacro

ISR_EXCEPTION_WITHOUT_ERRCODE 0
ISR_EXCEPTION_WITHOUT_ERRCODE 1
ISR_EXCEPTION_WITHOUT_ERRCODE 2
ISR_EXCEPTION_WITHOUT_ERRCODE 3
ISR_EXCEPTION_WITHOUT_ERRCODE 4
ISR_EXCEPTION_WITHOUT_ERRCODE 5
ISR_EXCEPTION_WITHOUT_ERRCODE 6
ISR_EXCEPTION_WITHOUT_ERRCODE 7
ISR_EXCEPTION_WITH_ERRCODE 8
ISR_EXCEPTION_WITHOUT_ERRCODE 9
ISR_EXCEPTION_WITH_ERRCODE 10
ISR_EXCEPTION_WITH_ERRCODE 11
ISR_EXCEPTION_WITH_ERRCODE 12
ISR_EXCEPTION_WITH_ERRCODE 13
ISR_EXCEPTION_WITH_ERRCODE 14
ISR_EXCEPTION_WITHOUT_ERRCODE 15
ISR_EXCEPTION_WITHOUT_ERRCODE 16
ISR_EXCEPTION_WITHOUT_ERRCODE 17
ISR_EXCEPTION_WITHOUT_ERRCODE 18
ISR_EXCEPTION_WITHOUT_ERRCODE 19
ISR_EXCEPTION_WITHOUT_ERRCODE 20
ISR_EXCEPTION_WITHOUT_ERRCODE 21
ISR_EXCEPTION_WITHOUT_ERRCODE 22
ISR_EXCEPTION_WITHOUT_ERRCODE 23
ISR_EXCEPTION_WITHOUT_ERRCODE 24
ISR_EXCEPTION_WITHOUT_ERRCODE 25
ISR_EXCEPTION_WITHOUT_ERRCODE 26
ISR_EXCEPTION_WITHOUT_ERRCODE 27
ISR_EXCEPTION_WITHOUT_ERRCODE 28
ISR_EXCEPTION_WITHOUT_ERRCODE 29
ISR_EXCEPTION_WITHOUT_ERRCODE 30
ISR_EXCEPTION_WITHOUT_ERRCODE 31

%assign i 32 
%rep    256-32 
        ISR_INTERRUPT i
%assign i i+1 
%endrep

extern int_handler
isr_common_stub:
    ; save complete context (multi-purpose&integer, no fpu/sse)
    ; the structure is also defined in system.h:struct regs
     push rax
     push rcx
     push rdx
     push rbx
     push Qword 0       ; FIXME: why is this 0 pushed?!
     push rbp
     push rsi
     push rdi
     push r8
     push r9
     push r10
     push r11
     push r12
     push r13
     push r14
     push r15
  
     xor rax, rax
     mov  ax, ds        ; Data Segment Descriptor
     push rax

     mov ax, es         ; ES
     push rax

     push fs            ; FS + GS
     push gs

     mov rax, cr3       ; CR 3
     push rax

     mov rax, cr2       ; CR 2
     push rax

     mov rdi, rsp           ; Param in RDI (RSP == pointer to saved registers on stack)
     call int_handler       ; int_handler(struct regs *r)

     ; restore context from stack
     pop rax        ; just remove cr2
     ;mov cr2, rax

     pop rax
     mov cr3, rax

     pop gs
     pop fs
     
     pop rax
     mov es, ax

     pop rax
     mov ds, ax

     pop r15
     pop r14
     pop r13
     pop r12
     pop r11
     pop r10
     pop r9
     pop r8
     pop rdi
     pop rsi
     pop rbp
     add rsp, 1*8           ; pushed 0 (why?)
     pop rbx
     pop rdx
     pop rcx
     pop rax

     add rsp, 2*8           ; two elements: err_code and vector-number

     iretq


; Wake-up code for SMP Application Processors
%include 'start_smp.inc'
    ; this include file is left by the APs in 32 bit protected mode.
    ; so code must follow to further set up the APs

[BITS 32]

    ; switch to 64 bit mode
    mov eax, 10100000b
    mov cr4, eax

    mov edx, 0x1000         ; know-how (set up in start64.asm, but we can't access symbols from there)
                            ; TODO: define global option (config.h?) where to put pml4
    mov cr3, edx

    mov ecx, 0xC000_0080
    rdmsr
    or eax, 0x0100
    wrmsr

    mov ebx, cr0
    or ebx, 0x8000_0001       ; Bit 32 (PG): enable paging; Bit 0 (PE): protection enable
    mov cr0, ebx

    lgdt [GDT64.Pointer]      ; same as BSP

    jmp GDT64.Code:Smp64      ; set code segment and enter 64-bit long mode

[BITS 64] 
Smp64:
    mov ax, GDT64.Data
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    ; TODO : set up a stack pointer rsp

    extern main_ap
    call main_ap
.endless:
    hlt
    jmp .endless


