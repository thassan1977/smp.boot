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
#include "mm.h"
#include "benchmark.h"
#include "smm.h"

extern volatile unsigned cpu_online;

/*
 * The payload is called by all CPUs after complete initialization.
 * A Barrier is executed immediately before, so they should come in shortly.
 */

static mutex_t mut = MUTEX_INITIALIZER;
static barrier_t barr = BARRIER_INITIALIZER(MAX_CPU+1);

void payload_benchmark()
{
    unsigned myid = my_cpu_info()->cpu_id;
    mutex_lock(&mut);
    if (barr.max == MAX_CPU+1) {
        barr.max = cpu_online;
        smm_deactivate();
    }
    mutex_unlock(&mut);


    if (myid == 0) printf("1 CPU hourglass -------------------------------\n");
    barrier(&barr);

    if (myid == 0) {
        hourglass(10);
    }

    if (cpu_online > 1) {
        if (myid == 0) printf("2 CPUs hourglass ------------------------------\n");
        barrier(&barr);

        if (myid == 0) {
            hourglass(10);
        } else if (myid == 1) {
            hourglass(10);
        }
    }

    barrier(&barr);



#   if 0
    /* needs at least two CPUs */
    if (cpu_online >= 2) {
        if (myid == 0) {
            /* call Task for CPU 0 */
            barrier(&barr);

            printf("CPU 0: udelay 5 Sek.\n");
            udelay(5*1000*1000);
            printf("CPU 0: exit now\n");
        } else if (myid == 1) {
            /* call Task for CPU 1 */
            barrier(&barr);

            printf("CPU 1: udelay 10 Sek.\n");
            udelay(10*1000*1000);
            printf("CPU 1: exit now\n");
        } 
    } else {
        printf("only one CPU active, this task needs at least two.\n");
    }
#   endif
}

