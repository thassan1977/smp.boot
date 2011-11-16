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


    if (myid == 0) printf("1 CPU hourglass (%u sec) -------------------------------\n", BENCH_HOURGLAS_SEC);
    barrier(&barr);

    if (myid == 0) {
        hourglass(BENCH_HOURGLAS_SEC);
    }

    if (cpu_online > 1) {
        if (myid == 0) printf("2 CPUs hourglass (%u sec) ------------------------------\n", BENCH_HOURGLAS_SEC);
        barrier(&barr);

        if (myid == 0) {
            hourglass(BENCH_HOURGLAS_SEC);
        } else if (myid == 1) {
            hourglass(BENCH_HOURGLAS_SEC);
        }
    }

    barrier(&barr);

    /*
     * allocate Buffer for memory benchmarks
     */
    if (myid == 0) {
        static void * p_buffer = NULL;
        size_t max_range = (1 << BENCH_MAX_RANGE_POW2); // 2^25 = 32 MB
        size_t i, j;
        p_buffer = heap_alloc(max_range/4096);       // one page = 4kB

        /* no need for pre-faulting, because pages are present after head_alloc()
         * but initialize them */
        memset(p_buffer, 0, max_range);


        printf("str.|range%4s %4s %4s %4s %4s %4s %4s %4s %4s %4s %4s %4s %4s %4s\n", 
                "4k", "8k", "16k", "32k", "64k", "128k", "256k", "512k", "1M", "2M", "4M", "8M", "16M", "32M");
        for (i=BENCH_MIN_STRIDE_POW2; i<=BENCH_MAX_STRIDE_POW2; i++) {                      /* stride */
            printf("%3u      ", (1<<i));
            for (j=BENCH_MIN_RANGE_POW2; j<=BENCH_MAX_RANGE_POW2; j++) {                /* range */
                unsigned long ret = range_stride(p_buffer, (1<<j), (1<<i));
                printf(" %4u", ret);
            }
            printf("\n");
        }
    }

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

