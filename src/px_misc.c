/*
 * Copyright (c) 1991, 1992, 1993 Brad Eacker,
 *              (Music, Intuition, Software, and Computers)
 * All Rights Reserved
 *
 * This file was taken from the php source code ext/dbase/db_misc.c
 */
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <sys/types.h>

#include "px_misc.h"

#ifdef WIN32
#define localtime_r( _clock, _result ) \
	( *(_result) = *localtime( (_clock) ), \
	(_result) )

#endif

/*
 * routine to change little endian long to host long
 * these functions are used read header data
 */
long get_long_le(const char *cp)
{
  unsigned long ret = 0;
  unsigned char *source = (unsigned char *)cp;
  
  if(NULL == cp)
    return 0;
  
  ret = *source++;
  ret |= ((unsigned long)(*source++) << 8);
  ret |= ((unsigned long)(*source++) << 16);
  ret |= ((unsigned long)(*source++) << 24);
  
  return (long)ret;
}

 * datablockhead.addDataSize is negativ if the datablock
 * is empty.
 */
short int get_short_le_s(const char *cp)
{
  unsigned short int ret = 0;
  unsigned char *source = (unsigned char *)cp;
  
  if(NULL == cp)
    return 0;
  
  ret = *source++;
  ret |= ((unsigned short int)(*source++) << 8);
  
  return (short int)ret;
}

long get_long_be(const char *cp)
{
  unsigned long ret = 0;
  unsigned char *source = (unsigned char *)cp;
  
  if(NULL == cp)
    return 0;
  
  ret = ((unsigned long)(*source++) << 24);
  ret |= ((unsigned long)(*source++) << 16);
  ret |= ((unsigned long)(*source++) << 8);
  ret |= *source++;
  
  return (long)ret;
}





