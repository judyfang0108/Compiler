#ifndef COMPILER_HW_COMMON_H
#define COMPILER_HW_COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_LEVEL 20
#define MAX_LENGTH 50
#define bool int
#define true 1
#define false 0

/* struct ... */
typedef struct Node
{
    char name[10];
    char type[10];
    int address;
    int lineno;
    char func_sig[10];
} NODE;

#endif /* COMPILER_HW_COMMON_H */






