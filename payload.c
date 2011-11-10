/*
 * =====================================================================================
 *
 *       Filename:  payload.c
 *
 *    Description:  This file contains some payloads to execute after the kernel has booted
 *
 *        Version:  1.0
 *        Created:  20.10.2011 09:21:36
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  Georg Wassen (gw) (), 
 *        Company:  
 *
 * =====================================================================================
 */

#include "sync.h"
#include "system.h"
#include "smp.h"
extern volatile unsigned cpu_online;

/*
 * The payload is called by all CPUs after complete initialization.
 * A Barrier is executed immediately before, so they should come in shortly.
 */

void payload_benchmark()
{
    unsigned myid = my_cpu_info()->cpu_id;
    static barrier_t b = BARRIER_INITIALIZER(2);
    static volatile uint32_t * volatile p_shared = NULL;

    /* needs at least two CPUs */
    if (cpu_online >= 2) {
        if (myid == 0) {
            /* call Task for CPU 0 */
            p_shared = heap_alloc(1);   // one page = 4kB
            printf("[0] p_shared = 0x%x\n", p_shared);
            udelay(1*1000*1000);
            barrier(&b);


            printf("CPU 0: udelay 5 Sek.\n");
            udelay(5*1000*1000);
            printf("CPU 0: exit now\n");
        } else if (myid == 1) {
            /* call Task for CPU 1 */
            barrier(&b);
            udelay(1*1000*1000);
            printf("[1] p_shared = 0x%x\n", p_shared);
            udelay(1*1000*1000);
            memset(p_shared, 1, 4096);

            printf("CPU 1: udelay 10 Sek.\n");
            udelay(10*1000*1000);
            printf("CPU 1: exit now\n");
        } 
    } else {
        printf("only one CPU active, this task needs at least two.\n");
    }
}

