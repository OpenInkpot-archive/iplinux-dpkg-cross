#
# preset values of configure variables for cross-compiling to any linux system
#
# If you have additions to this file, please tell <roman@debian.org>
# so they can be included in the package.
#
# These values cannot determined when cross-compiling, because configure would
# have to run a target arch test program, which is not possible on the build
# host. So supply them manually...
#
ac_cv_header_stdc=yes
ac_cv_func_closedir_void=no
kb_cv_func_putenv_malloc=no
ac_cv_func_vfork=yes
ac_cv_func_setvbuf_reversed=no

# the following are used by ncurses, but the values aren't cached, so
# they can't be preset here :-( But configure doesn't abort with
# an error if the value cannot be determined, it uses a reasonable default
#nc_cv_link_dataonly=
#nc_cv_use_tiocgwinsz=
#nc_cv_sizeof_bool=

. `dirname $ac_site_file`/cross-config.common
ac_cv_linux_vers=2.6.12
jm_cv_func_working_re_compile_pattern=yes
ac_use_included_regex=no
ac_cv_func_malloc_0_nonnull=yes
ac_cv_have_abstract_sockets=yes
ac_cv_func_posix_getpwnam_r=yes
glib_cv_monotonic_clock=yes
sudo_cv_uid_t_len=10
