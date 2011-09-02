#ifndef __SYSTEM_H
#define __SYSTEM_H

#include <stddef.h>

/* MAIN.C */
void *memcpy(void *dest, const void *src, int count);
void *memset(void *dest, int val, int count);
unsigned short *memsetw(unsigned short *dest, unsigned short val, int count);
int strlen(const char *str);
unsigned char inportb (unsigned short _port);
void outportb (unsigned short _port, unsigned char _data);
#define NULL ((void*)0)

/* SCRN.H */
void cls();
void putch(char c);
void puts(char *str);
void settextcolor(unsigned char forecolor, unsigned char backcolor);
void init_video();
void itoa (char *buf, int base, int d);
void printf (const char *format, ...);

#endif
