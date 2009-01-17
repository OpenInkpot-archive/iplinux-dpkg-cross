#                                               -*- Autoconf -*-
# Process this file with autogen.sh to produce a configure script.
AC_PREREQ(2.59)
AC_INIT([dummy], [0.0.0], [bossekr@debian.org])

dnl Check what platform we are running on.
AC_CANONICAL_TARGET

dnl Initialize GNU Automake, and require Automake 1.7 or better.
AM_INIT_AUTOMAKE([1.7])

dnl Do not try to rebuild the configure files by default.
AM_MAINTAINER_MODE

AC_C_BIGENDIAN
AC_C_CHAR_UNSIGNED

AC_CHECK_SIZEOF(long long)
AC_CHECK_SIZEOF(unsigned long long)
AC_CHECK_SIZEOF(long)
AC_CHECK_SIZEOF(unsigned long)
AC_CHECK_SIZEOF(int)
AC_CHECK_SIZEOF(unsigned int)
AC_CHECK_SIZEOF(short)
AC_CHECK_SIZEOF(unsigned short)
AC_CHECK_SIZEOF(char)
AC_CHECK_SIZEOF(unsigned char)
AC_CHECK_SIZEOF(signed char)
AC_CHECK_SIZEOF(float)
AC_CHECK_SIZEOF(double)
AC_CHECK_SIZEOF(long double)
AC_CHECK_SIZEOF(void *)
AC_CHECK_SIZEOF(char *)
AC_CHECK_SIZEOF(off_t)

AC_CONFIG_FILES([Makefile])
AC_CONFIG_COMMANDS_PRE([
  echo ""
  echo "Save the ac_cv_* lines in cross-config.$host_cpu:"
  echo ""
  echo ac_cv_c_bigendian=$ac_cv_c_bigendian
  echo ac_cv_c_char_unsigned=$ac_cv_c_char_unsigned
  echo ac_cv_sizeof_long_long=$ac_cv_sizeof_long_long
  echo ac_cv_sizeof_unsigned_long_long=$ac_cv_sizeof_unsigned_long_long
  echo ac_cv_sizeof_long=$ac_cv_sizeof_long
  echo ac_cv_sizeof_unsigned_long=$ac_cv_sizeof_unsigned_long
  echo ac_cv_sizeof_int=$ac_cv_sizeof_int
  echo ac_cv_sizeof_unsigned_int=$ac_cv_sizeof_unsigned_int
  echo ac_cv_sizeof_short=$ac_cv_sizeof_short
  echo ac_cv_sizeof_unsigned_short=$ac_cv_sizeof_unsigned_short
  echo ac_cv_sizeof_char=$ac_cv_sizeof_char
  echo ac_cv_sizeof_unsigned_char=$ac_cv_sizeof_unsigned_char
  echo ac_cv_sizeof_signed_char=$ac_cv_sizeof_signed_char
  echo ac_cv_sizeof_float=$ac_cv_sizeof_float
  echo ac_cv_sizeof_double=$ac_cv_sizeof_double
  echo ac_cv_sizeof_long_double=$ac_cv_sizeof_long_double
  echo ac_cv_sizeof_void_p=$ac_cv_sizeof_void_p
  echo ac_cv_sizeof_char_p=$ac_cv_sizeof_char_p
  echo ac_cv_sizeof_off_t=$ac_cv_sizeof_off_t
  echo ""])
AC_OUTPUT
