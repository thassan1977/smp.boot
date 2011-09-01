#include <system.h>
#include <multiboot.h>

void print_multiboot_info(multiboot_info_t *mbi) 
{
    char mem_type[][10] = {"mem", "other"};

    printf("Multiboot-Flags: 0x%x\n", mbi->flags);

    if (mbi->flags & (1<<0)) {
        printf("flags[0] - mem_lower: 0x%x=%d  mem_upper: 0x%x=%d\n", mbi->mem_lower, mbi->mem_lower, mbi->mem_upper, mbi->mem_upper);
    }

    if (mbi->flags & (1<<1)) {
        printf("flags[1] - boot_device: %x %x %x %x (Part 3/2/1 / Drive)\n", mbi->boot_device&0xFF, (mbi->boot_device>>8)&0xFF, 
                (mbi->boot_device>>16)&0xFF, (mbi->boot_device>>24)&0xFF);
    }

    if (mbi->flags & (1<<2)) {
        printf("flags[2] - cmdline: '%s'\n", mbi->cmdline);
    }

    if (mbi->flags & (1<<3)) {
        printf("flags[3] - mods_count: %d  mods_addr: 0x%x\n", mbi->mods_count, mbi->mods_addr);
        int i;
        for (i=0; i<mbi->mods_count; i++) {
            printf("  mod[%d]...\n", i);
        }
    }

    if (mbi->flags & (1<<4)) {
        printf("flags[4] - Symbol table for a.out image...\n");
    }

    if (mbi->flags & (1<<5)) {
        printf("flags[5] - Section header table for ELF kernel...\n");
    }

    if (mbi->flags & (1<<6)) {
        printf("flags[6] - mmap_length: %d  mmap_addr: 0x%x\n", mbi->mmap_length, mbi->mmap_addr);
        multiboot_memory_map_t* p = (multiboot_memory_map_t*)(long)mbi->mmap_addr;
        for ( ; p < (multiboot_memory_map_t*)(long)(mbi->mmap_addr+mbi->mmap_length); p = ((void*)p + p->size + 4)) {
            printf("  mmap[0x%x] - addr:0x%x  len:0x%x  type: %d (%s)\n",
                   p, (multiboot_uint32_t)(p->addr), (multiboot_uint32_t)(p->len), p->type, mem_type[p->type==1?0:1]);
        }
    }

    /* more bits available in flags, but their display is not implemented, yet */
    /* see: http://www.gnu.org/software/grub/manual/multiboot/multiboot.html#Boot-information-format */
}

void cpuid(unsigned func, unsigned *eax, unsigned *ebx, unsigned *ecx, unsigned *edx)
{
    asm volatile ("cpuid" : "=a"(*eax), "=b"(ebx), "=c"(ecx), "=d"(edx) : "a"(func));
}
void print_smp_info(void)
{
    unsigned eax, ebx, ecx, edx;
    volatile unsigned *register_apic_id;
    unsigned i;

    cpuid(0x0B, &eax, &ebx, &ecx, &edx);
    printf("APIC ID from CPUID.0BH:EDX[31:0]: %d\n", edx);

    register_apic_id = 0xFEE00000 + 0x20;
    i = *register_apic_id;
    i = i >> 24;
    printf("local APIC ID from register: %d\n", i);


}

static inline void stackdump(int from, int to)
{
    long *sp;
    long *p;
#   ifdef __X86_64__
    asm volatile ("mov %%rsp, %%rax" : "=a"(sp));
#   else
    asm volatile ("mov %%esp, %%eax" : "=a"(sp));
#   endif
    printf("sp: %x\n", sp);
    for (p = sp-to; p <= sp-from; p++) {
        printf("[%x]   %x\n", p, *p);
    }
}

void main(multiboot_info_t *mbi, void *ip)
{
    init_video();

    puts("my kernel is running in main now...\n");

    unsigned eax, ebx, ecx, edx;
    cpuid(0x80000001, &eax, &ebx, &ecx, &edx);
    printf("support 1 GB pages: %d\n", edx & (1<<26));

    //print_multiboot_info(mbi);
    print_smp_info();

    printf("The end.\n");

}
		
