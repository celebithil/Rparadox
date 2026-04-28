#ifndef __PX_MISC_H__
#define __PX_MISC_H__

extern long get_long_le(const char *cp);
extern unsigned short int get_short_le(const char *cp);
extern short int get_short_le_s(const char *cp);


extern double get_double_le(const char *cp);


extern long get_long_be(const char *cp);
extern short int get_short_be(const char *cp);


extern double get_double_be(const char *cp);




extern int px_date_year(char *cp);
extern int px_date_month(char *cp);
extern int px_date_day(char *cp);

extern int px_get_date(char *cp);

#endif
