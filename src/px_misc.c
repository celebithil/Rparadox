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
#include "paradox.h"
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/types.h>

#include "px_misc.h"

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

/*
 * routine to change little endian short to host short
 */
unsigned short int get_short_le(const char *cp)
{
	unsigned short int ret;
	unsigned char *source = (unsigned char *)cp;

	if(NULL == cp)
		return 0;

	ret = *source++;
	ret += ((*source++)<<8);

	return ret;
}

/*
 * routine to change big endian long to host long
 * these functions are used read table data
 */
long get_long_be(const char *cp)
{
  uint32_t raw;
  unsigned char *source = (unsigned char *)cp;

  if(NULL == cp)
    return 0;

  raw = ((uint32_t)source[0] << 24) |
        ((uint32_t)source[1] << 16) |
        ((uint32_t)source[2] << 8) |
        (uint32_t)source[3];

  /* Preserve the signed interpretation of the 32-bit value, as the
   * original int-based implementation did. PX_get_data_long() relies on
   * this sign extension: a zero-extending variant shifts negative Long
   * values by 2^32. */
  if(raw & UINT32_C(0x80000000))
    return (long)((int64_t)raw - (INT64_C(1) << 32));
  return (long)raw;
}

/*
 * routine to change little endian short to host short
 */
short int get_short_be(const char *cp)
{
  unsigned short int ret = 0;
  unsigned char *source = (unsigned char *)cp;
  
  if(NULL == cp)
    return 0;
  
  ret = ((unsigned short int)(*source++) << 8);
  ret |= *source++;
  
  return (short int)ret;
}

double get_double_be(const char *cp)
{
	double ret;
	unsigned char *dp = (unsigned char *)&ret;

	if(NULL == cp)
		return 0.0;

#ifdef WORDS_BIGENDIAN
	memcpy(dp, cp, 8);
#else
	dp[7] = *cp++;
	dp[6] = *cp++;
	dp[5] = *cp++;
	dp[4] = *cp++;
	dp[3] = *cp++;
	dp[2] = *cp++;
	dp[1] = *cp++;
	dp[0] = *cp++;
#endif
	return ret;
}

/*
 * Local variables:
 * tab-width: 4
 * c-basic-offset: 4
 * End:
 * vim600: sw=4 ts=4 fdm=marker
 * vim<600: sw=4 ts=4
 */

