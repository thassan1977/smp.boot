
CFILES=$(shell ls *.c | grep -v boot32.c )
O32FILES=$(CFILES:.c=.o32)
O64FILES=$(CFILES:.c=.o64)
HFILES=$(shell ls *.h)

ASMFILES=$(shell ls *.asm)

OPT=2

VERBOSE=@
#VERBOSE=

CFLAGS=-c -O$(OPT) -std=c99
# -O          - basic optimization
CFLAGS+=-Wall -Wextra -Wno-main -Wno-unused-function -Wno-pragmas
# -Wall       - give warnings (on most checks)
# -Wextra     - give even more warnings (on all checks)
# -Wno-main   - suppress warning on main and its parameters (this is a kernel!)
# -Wno-unused-function - suppress warning about unused function (during development...)
# -Wno-pragmas - don't warn about unknown parameters to #pragmas (GCC 4.5 does not know -Wunused-but-set-variable )
CFLAGS+=-fstrength-reduce -fomit-frame-pointer -finline-functions -nostdinc -fno-builtin -fno-zero-initialized-in-bss 
# -fstrengh-reduce
# -fomit-frame-pointer  - don't use frame pointer if not needed (e.g. leaf functions). Makes debugging impossible. Enabled by -O >= 1
# -finline-functions
# -fnostdinc            - don't include standards libs
# -no-builtin           - don't use builtin functions for libc (memcpy etc.), we have our own implementations.
# -no-zero-initialized-in-bss 
#  						- don't move variables, that are initialized with 0 (zero) to the .bss segment
#  						  because that will not be filled with zeros (the kernel is not loaded by ld.so)
CFLAGS+=-I .
# -I . 					- add include directory '.'

# default nbr of CPUs for QEMU smp
SMP=2
# default command line for QEMU
CMDLINE=test

C32FLAGS=$(CFLAGS)
C64FLAGS=$(CFLAGS) -ffreestanding -mcmodel=large -mno-red-zone -mno-mmx -mno-sse -mno-sse2 -mno-sse3 -mno-3dnow
# extra Parameters for 64 bit C code
# -ffreestanding
# -mcmodel=large
# -mno-red-zone   		- do not assume a red-zone (reserved space on stack)
# -mno-mmx
# -mno-sse
# -mno-sse2
# -mno-sse3
# -mno-3dnow

CC=gcc
LD=ld
NASM=nasm
READELF=readelf
OBJCOPY=objcopy
CTAGS=ctags
QEMU32=qemu
QEMU64=qemu-system-x86_64

# search for color-gcc and use it if available
COLORGCC=$(shell which color-gcc)
ifneq ($(COLORGCC), "")
	CC=$(COLORGCC)
endif


CC32=$(CC) -m32
CC64=$(CC) -m64

# symbols from 64 bit kernel (kernel64.elf64) to be transferred to kernel64.bin
KERNEL64_SYMBOLS="Realm32 Realm64 main hw_info isr0 idt"

default : tags kernel32.bin kernel64.bin

help :
	@echo 'Makefile for Multiboot kernel'
	@echo 'available targets:'
	@echo '  default         default target is: tags kernel32 kernel64'
	@echo '  debug           show internal variables (for debug purposes)'
	@echo '  tags            create ctags table'
	@echo '  depend          recreate dependencies (is done automatically when needed)'
	@echo '  kernel32        -> kernel32.bin'
	@echo '  kernel64        -> kernel64.bin'
	@echo '  q32             build kernel32.bin and boot it in QEmu'
	@echo '  q64             build kernel64.bin and boot it in QEmu'
	@echo '  s32             build kernel32.bin and boot it in SMP-QEmu (SMP=2)'
	@echo '  s64             build kernel64.bin and boot it in SMP-QEmu (SMP=2)'
	@echo '                  use "make SMP=4 s64" to configure the number of CPUs'
	@echo '  xaxis           build both kernels and copy to xaxis (using scp)'
	@echo '  clean           remove intermediate and built files'

debug :
	@echo CFILES: $(CFILES)
	@echo O32FILES: $(O32FILES)
	@echo O64FILES: $(O64FILES)
	@echo CFLAGS: $(CFLAGS)
	@echo COLORGCC: $(COLORGCC)
	@echo CC: $(CC)

config.inc : config.h
	@echo CONVERT $< '->' $@
	@echo "; do not edit this file, it is generated from config.h" > $@
	@echo "; vim: set ft=asm:" >> $@
	@grep '^#' $< | sed 's/^#/%/' >> $@

# PHONY: update temp file in any case
version.tmp :
	@echo "UPDATE version.tmp"
	@echo '#define SVN_REV "'$$(svnversion)'"' > version.tmp
	@echo '#define OPT "'$(OPT)'"' >> version.tmp

# only if tmp and h differ: update version.h
# This way, the depending files are only updated, when the content changes (not when the timestamp changes; which is every call to make)
version.h : version.tmp
	@echo "UPDATE version.h"
	@if test -r version.h && diff version.h version.tmp 2>&1 >/dev/null ; then rm version.tmp; else mv version.tmp version.h; fi


# 32 bit start code for 32 bit kernel
start32.o : start32.asm start.asm start_smp.inc config.inc
	@echo NASM $< '->' $@
	$(VERBOSE)nasm -f aout -o $@ $<

# 32 bit start code for 64 bit kernel
start64.o : start64.asm start.asm
	@echo NASM $< '->' $@
	$(VERBOSE)nasm -f elf32 -o $@ $<

# 64 bit jump code for 64 bit kernel
jump64.o : jump64.asm start_smp.inc config.inc
	@echo NASM $< '->' $@
	$(VERBOSE)nasm -f elf64 -o $@ $<

screen.o : screen.c
	@echo CC32 $< '->' $@
	$(VERBOSE)$(CC32) $(C32FLAGS) -DEARLY -o $@ $<

# C files into 32 bit objects
$(O32FILES) : %.o32 : %.c
	@echo CC32 $< '->' $@
	$(VERBOSE)$(CC32) $(C32FLAGS) -o $@ $<

boot32.o : boot32.c
	@echo CC32 $< '->' $@
	$(VERBOSE)$(CC32) $(C32FLAGS) -o $@ $<


# C files into 64 bit objects
$(O64FILES) : %.o64 : %.c
	@echo CC64 $< '->' $@
	$(VERBOSE)$(CC64) $(C64FLAGS) -o $@ $<

# link 32 bit kernel (a.out-multiboot)
kernel32 : kernel32.bin
kernel32.bin : link32.ld start32.o boot32.o $(O32FILES) 
	@echo LD $^ '->' $@
	$(VERBOSE)$(LD) -T link32.ld -m i386linux --print-map -Map=kernel32.map -o $@ start32.o boot32.o $(O32FILES)

# link 64 bit kernel that will be embedded into kernel64.bin
kernel64.elf64 : link64.ld jump64.o $(O64FILES) 
	@echo LD $^ '->' $@
	$(VERBOSE)$(LD) -nostdlib -nodefaultlibs -T link64.ld  -o kernel64.elf64 jump64.o $(O64FILES)

# generate .KERNEL64 section's data from 64 bit kernel
kernel64.section : kernel64.elf64
	@echo GETSECTION $^ '->' $@
	$(VERBOSE)$(READELF) -SW "kernel64.elf64" | python getsection.py 0x140000 kernel64.elf64 kernel64.section

# export wanted symbols from KERNEL64 from 64 bit kernel
kernel64.symbols : kernel64.elf64
	@echo GETSYMBOLS $^ '->' $@
	$(VERBOSE)$(READELF) -sW "kernel64.elf64" | python getsymbols.py $(KERNEL64_SYMBOLS) kernel64.symbols

# add section .KERNEL64 with 64 bit code and data to 32 bit start code (will still be ELF32)
kernel64.o : start64.o kernel64.section
	@echo OBJCOPY $^ '->' $@
	$(VERBOSE)$(OBJCOPY) --add-section .KERNEL64="kernel64.section" --set-section-flag .KERNEL64=alloc,data,load,contents start64.o kernel64.o

# finally link 32 bit start code with implanted .KERNEL64 (opaque blob)
# to a relocated ELF32-multiboot kernel image
kernel64 : kernel64.bin
kernel64.bin : link_start64.ld kernel64.symbols kernel64.o boot32.o screen.o lib.o32
	@echo LD $^ '->' $@
	$(VERBOSE)$(LD) -melf_i386 -T link_start64.ld -T kernel64.symbols   kernel64.o boot32.o screen.o lib.o32 -o kernel64.bin 

depend : .depend
.depend : version.h $(HFILES) $(CFILES) boot32.c 
	@echo DEPEND $^
	$(VERBOSE)$(CC) -MM $^ | sed "s+\(.*\):\(.*\)+\1 \132 \164 :\2+" > $@

# The sed regex prints every target left of ':' three times: the original 
# and two versions for 32 and 64 bit objects: 
#     xxx.o : xxx.c yyy.h zzz.h
# becomes:
#     xxx.o xxx.o32 xxx.o64 : xxx.c yyy.h zzz.h
# The part right of the colon is not changed.
# The regex catches the parts left and right of the ':' in '\(.*\)' (with arbitrary characters)
# and the catched expressions are issued by \1 and \2 (left one tree times, separated by space \n)

-include .depend

tags : $(CFILES) boot32.c $(HFILES) $(ASMFILES)
	@echo CTAGS
	$(VERBOSE)$(CTAGS) -R *.c *.h *.asm

# start QEMU with 32 or 64 bit
q32 : kernel32.bin
	$(VERBOSE)$(QEMU32) -kernel kernel32.bin -append "$(CMDLINE)"

q64 : kernel64.bin
	$(VERBOSE)$(QEMU64) -kernel kernel64.bin -append "$(CMDLINE)"

smp : s64
s32 : kernel32.bin
	$(VERBOSE)$(QEMU32) -smp $(SMP) -kernel kernel32.bin -append "$(CMDLINE)"

s64 : kernel64.bin
	$(VERBOSE)$(QEMU64) -smp $(SMP) -kernel kernel64.bin -append "$(CMDLINE)"

xaxis : kernel32.bin kernel64.bin
	scp kernel??.bin root@xaxis:/boot/

# housekeeping
clean :
	-rm *.o *.o32 *.o64 *.symbols *.section *.bin *.elf64 .depend config.inc tags

.PHONY : default help debug q32 q64 s32 s64 kernel32 kernel64 clean depend version.tmp
