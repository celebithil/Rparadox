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
#include <stdio.h>
#include <string.h>
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
 * routine to change little endian short to host short
 * This one returns a signed integer because reading
 * datablockhead.addDataSize needs to be done signed.
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

double get_double_le(const char *cp)
{
	double ret;
	unsigned char *dp = (unsigned char *)&ret;

	if(NULL == cp)
		return 0.0;

#ifdef WORDS_BIGENDIAN
	dp[7] = *cp++;
	dp[6] = *cp++;
	dp[5] = *cp++;
	dp[4] = *cp++;
	dp[3] = *cp++;
	dp[2] = *cp++;
	dp[1] = *cp++;
	dp[0] = *cp++;
#else
	memcpy(dp, cp, 8);
#endif
	return ret;
}

/*
 * routine to change big endian long to host long
 * these functions are used read table data
 */
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

void copy_fill(char *dp, char *sp, int len)
{
	while (*sp && len > 0) {
		*dp++ = *sp++;
		len--;
	}
	while (len-- > 0)
		*dp++ = ' ';
}

void copy_crimp(char *dp, char *sp, int len)
{
	while (len-- > 0) {
		*dp++ = *sp++;
	}
	*dp = 0;
	for (dp-- ; *dp == ' '; dp--) {
		*dp = 0;
	}

}

int px_get_date(char *cp) {

	return (*((int *) cp));
}

int px_date_year(char *cp)
{
	int	year, i;

	for (year = 0, i = 0; i < 4; i++)
		year = year * 10 + (cp[i] - '0');
	return year;
}

int px_date_month(char *cp)
{
	int	month, i;

	for (month = 0, i = 4; i < 6; i++)
		month = month * 10 + (cp[i] - '0');
	return month;
}

int px_date_day(char *cp)
{
	int	day, i;

	for (day = 0, i = 6; i < 8; i++)
		day = day * 10 + (cp[i] - '0');
	return day;
}

void hex_dump(FILE *outfp, char *p, int len) {
	int i;

	if(NULL == p)
		fprintf(outfp, "NULL");

	for(i=0; i<len; i++) {
		if(i%16 == 0)
			fprintf(outfp, "\n%p: ", &p[i]);
		fprintf(outfp, "%02X ", p[i]);
	}
	fprintf(outfp, "\n");
}

/*
 * Local variables:
 * tab-width: 4
 * c-basic-offset: 4
 * End:
 * vim600: sw=4 ts=4 fdm=marker
 * vim<600: sw=4 ts=4
 */

