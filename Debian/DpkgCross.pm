package Debian::DpkgCross;
use File::HomeDir;
use File::Basename;
use File::Temp qw/tempfile tempdir/;
use Config::Auto;
use Cwd;
use warnings;
use strict;

# Version of dpkg-cross environment.
my $DPKGCROSSVERSION = "2.3.0";

require Exporter;

use vars qw (@ISA @EXPORT @EXPORT_OK $conffile $private_conffile
$progname %archtable %archdetecttable %crossprefixtable
%std_tools %pkgvars %allcrossroots $arch $default_arch
$deb_host_gnu_type $crossbase $crossprefix $crossdir $crossbin
$crosslib $crossroot $crossinc $crosslib64 $crosslib32 $package $mode $tool_
%config @keepdeps %allcrossroots @removedeps $maintainer
$compilerpath %debug_data);
@ISA       = qw(Exporter);
@EXPORT    = qw( read_config setup get_architecture create_tmpdir
convert_path get_config get_version rewrite_pkg_name dump_debug_data
check_arch convert_filename detect_arch get_endianness);
@EXPORT_OK = qw(dpkgcross_application simplify_path setup_cross_env
get_tool convert_ld_library_path get_keepdeps get_removedeps );

=pod

=head1 Name

Debian::DpkgCross - Package of dpkg-cross commonly used functions

The 2.x series of dpkg-cross is seeking to achieve its own removal
by incorporating as much cross-building support as possible into
dpkg itself. The number, scope and range of functions supported
by this package is therefore only going to decrease. Any newly-written
code using this package will need to keep up with changes in dpkg.
Developers are recommended to join the debian-dpkg and debian-embedded
mailing lists and keep their code under review.

=head1 Copyright and License

=over

=item *

Copyright (C) 2004  Nikita Youshchenko <yoush@cs.msu.su>

=item *

Copyright (C) 2004  Raphael Bossek <bossekr@debian.org>

=item *

Copyright (c) 2007-2008  Neil Williams <codehelp@debian.org>
=back

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

=head1 Bugs

Please report bugs via the Debian Bug Tracking System.

=head1 Support

All enquiries to the C<<debian-embedded@lists.debian.org>> mailing list.

=cut

# Determine if the system wide or user defined cross-compile configuration
# have to be read.
$conffile = "/etc/dpkg-cross/cross-compile";
%debug_data=();
my $home = File::HomeDir->my_home;
# handle a missing $home value.
$home = cwd if (!defined($home));
$private_conffile = "${home}/.dpkg-cross/cross-compile";

# Name of the calling application.
$progname = basename($0);

# Conversion table for Debian GNU/Linux architecture name ('$arch') to GNU
# type. This lists additional arch names that are not already supported by
# dpkg-architecture.
# Need to support uclibc formats and remove those that differ from dpkg.
# Migrate these into the conffile and allow anything the user specifies
# in that file.
%archtable = (
	'armeb' => 'armeb-linux-gnueabi', #XXX This differs from dpkg-architecture
	'hurd-i386' => 'i386-gnu',        #XXX This differs from dpkg-architecture
	's390x' => 's390-linux-gnu',      #XXX This differs from dpkg-architecture
	'openbsd-i386' => 'i386-openbsd', #XXX This differs from dpkg-architecture
	'freebsd-i386' => 'i386-freebsd', #XXX This differs from dpkg-architecture
	'darwin-i386' => 'i386-darwin',   #XXX This differs from dpkg-architecture
	'win32-i386' => 'i386-cygwin',
);

# Regexps to parse 'file' output to detect arch of ELF binary
# Note that it is not always possible to restore Debian architecture
# name by binary: e.g. i386-linux and i386-hurd use same ELF shared
# library format.
# Special arch name 'AR' is used to detect ar archives that need
# to be processed in special way
# FIXME: table is incomplete.
%archdetecttable = (
	'i386' => 'ELF 32-bit LSB .* 80386',
	'sparc' => 'ELF 32-bit MSB .* SPARC',
	'sparc64' => 'ELF 64-bit MSB .* SPARC',
	'alpha' => 'ELF 64-bit LSB .* Alpha',
	'm68k' => 'ELF 32-bit MSB .* 680[02]0',
	'arm' => 'ELF 32-bit LSB .* ARM',
	'armeb' => 'ELF 32-bit MSB .* ARM',
	'armel' => 'ELF 32-bit LSB .* SYSV',
	'powerpc' => 'ELF 32-bit MSB .* PowerPC',
	'powerpc64' => 'ELF 64-bit MSB .* PowerPC',
	'mips' => 'ELF 32-bit MSB .* MIPS',
	'mipsel' => 'ELF 32-bit LSB .* MIPS',
	'hppa' => 'ELF 32-bit MSB .* PA-RISC',
	's390' => 'ELF 32-bit MSB .* S.390',
	's390x' => 'ELF 64-bit MSB .* S.390',
	'ia64' => 'ELF 64-bit LSB .* IA-64',
 	'm32r' => 'ELF 32-bit MSB .* M32R',
	'amd64' => 'ELF 64-bit LSB .* x86-64',
	'w32-i386' => '80386 COFF',
	'AR' => 'current ar archive');

# Lists of possible crossprefix'es for each architecture
# FIXME: table is incomplete.
%crossprefixtable = (
	"i386" => [ "i486-linux-gnu-", "i386-linux-gnu-", "i486-linux-", "i386-linux-", "i486-gnu-", "i386-gnu-" ],
	"sparc" => [ "sparc-linux-gnu-", "sparc-linux-", "sparc64-linux-gnu-", "sparc64-linux-" ],
	"sparc64" => [ "sparc64-linux-gnu", "sparc64-linux-", "sparc-linux-gnu-", "sparc-linux-" ],
	"alpha" => [ "alpha-linux-gnu-", "alpha-linux-" ],
	"m68k" => [ "m68k-linux-gnu-", "m68k-linux-" ],
	"arm" => [ "arm-linux-gnu-", "arm-linux-" ],
	"armeb" => [ "armeb-linux-gnu-", "armeb-linux-" ],
	"powerpc" => [ "powerpc-linux-gnu-", "powerpc-linux-", "ppc-linux-gnu-", "ppc-linux-" ],
	"powerpc64" => [ "powerpc64-linux-gnu-", "powerpc64-linux-", "ppc64-linux-gnu-", "ppc64-linux-",
			 "powerpc-linux-gnu-", "powerpc-linux-", "ppc-linux-gnu-", "ppc-linux-" ],
	"mips" => [ "mips-linux-gnu-", "mips-linux-", "mips64-linux-gnu-", "mips64-linux-" ],
	"mipsel" => [ "mipsel-linux-gnu-", "mipsel-linux-", "mips64el-linux-gnu-", "mips64el-linux-" ],
	"hppa" => [ "hppa-linux-gnu-", "hppa-linux-" ],
	"s390" => [ "s390-linux-gnu-", "s390-linux-", "s390x-linux-gnu-", "s390x-linux-" ],
	"s390x" => [ "s390x-linux-gnu-", "s390x-linux-", "s390-linux-gnu-", "s390-linux-" ],
	"ia64" => [ "ia64-linux-gnu-", "ia64-linux-" ],
	"m32r" => [ "m32r-linux-gnu-", "m32r-linux-" ],
	"amd64" => [ "amd64-linux-gnu-", "amd64-linux-", "x86_64-linux-gnu-", "x86_64-linux-",
			"x86-64-linux-gnu-", "x86-64-linux-" ],
	"w32-i386" => [ "i586-mingw32msvc-" ]);

# All environment variables for compiler and binutils with their corresponding
# application name which will be modified for cross-compiling.
# For strip we have a wrapper, so it isn't mentioned here.

=head1 MAKEFLAGS

See bug #437507 Even if the other flags are needed CC, GCC and
other compiler names should *NOT* be overridden in $ENV{'MAKEFLAGS'}
because this prevents packages compiling and running build tools
using CC_FOR_BUILD.
CDBS packages need to declare an empty override variable in
debian/rules:

 DEB_CONFIGURE_SCRIPT_ENV=

Depending on progress with dpkg cross-building support, the
remaining overrides may also be removed. Do not rely on these
being set.

=cut

%std_tools = (
	AS => "as",
	LD => "ld",
	AR => "ar",
	NM => "nm",
	RANLIB => "ranlib",
	RC => "windres");

$debug_data{'std_tools'} = \%std_tools;

# Contains '$crossroot' definitions by '$arch' readed from configuration.
# '$crossroot' is set by setup() if '$arch' is known from this hash table.
%allcrossroots = ();

=head1 read_config

Read '$conffile' and save the definition in global variables all
recognised variables.

'$crossroot' will be set by setup(). Until setup() is called all
"crossroot-<arch>" settings are stored within '%allcrossroots'.

All package variables are stored within '%conf'.

No variables are skipped.

return: none

=cut

sub read_config {
	my $conf = Config::Auto::parse("$conffile");

	$default_arch = $conf->{'default_arch'};
	$crossbase = $conf->{'crossbase'};
	$crossprefix = $conf->{'crossprefix'};
	$crossdir = $conf->{'crossdir'};
	$crossbin = $conf->{'crossbin'};
	$crosslib = $conf->{'crosslib'};
	$crosslib64 = $conf->{'crosslib64'};
	$crosslib32 = $conf->{'crosslib32'};
	$crossinc = $conf->{'crossinc'};
	$maintainer = $conf->{'maintainer'};
	$compilerpath = $conf->{'compilerpath'};
	my $kd = $conf->{'keepdeps'};
	push @keepdeps, @$kd;
	my $rd = $conf->{'removedeps'};
	push @removedeps, @$rd;

	# the key is actually crossroots-${archtype}
	foreach my $acr (keys %$conf)
	{
		if ($acr =~ /^crossroot-(\S+)$/)
		{
			my $k = "crossroot-$1";
			$allcrossroots{$1} = $conf->{"$crossroot"};
		}
	}
	if (-f "$private_conffile")
	{
		# also check $private_conffile and merge
		$conf = Config::Auto::parse("$private_conffile");
		$default_arch ||= $conf->{'default_arch'};
		$crossbase ||= $conf->{'crossbase'};
		$crossprefix ||= $conf->{'crossprefix'};
		$crossdir ||= $conf->{'crossdir'};
		$crossbin ||= $conf->{'crossbin'};
		$crosslib ||= $conf->{'crosslib'};
		$crosslib64 ||= $conf->{'crosslib64'};
		$crosslib32 ||= $conf->{'crosslib32'};
		$crossinc ||= $conf->{'crossinc'};
		$maintainer ||= $conf->{'maintainer'};
		$compilerpath ||= $conf->{'compilerpath'};
		$kd = $conf->{'keepdeps'};
		push @keepdeps, @$kd;
		$rd = $conf->{'removedeps'};
		push @removedeps, @$rd;
		# the key is actually crossroots-${archtype}
		foreach my $acr (keys %$conf)
		{
			if ($acr =~ /^crossroot-(\S+)$/)
			{
				my $k = "crossroot-$1";
				$allcrossroots{$1} = $conf->{"$crossroot"};
			}
		}
	}
}

=head1 get_config

Return the current configuration from read_config
as a hash reference.

=cut

sub get_config {
	return \%config;
}

=head1 get_version

Return the current DpkgCross version string used by all
dpkg-cross scripts.

=cut

sub get_version {
	return $DPKGCROSSVERSION;
}

=head1 dump_debug_data

Return a hashtable of assorted debug data collated
during the current run that can be processed using
Data::Dumper.

=cut

sub dump_debug_data {
	return \%debug_data;
}

=head1 rewrite_pkg_name

Converts a package name into the dpkg-cross package name.

$1 - the package name to check and convert if needed
return - the cross-package name

=cut

sub rewrite_pkg_name {
	my $name = shift;

	$name .= "-$arch-cross" if $name !~ /-\Q$arch\E-cross$/;
	return $name;
}

=head1 convert_filename($)

Converts an original .deb filename into the dpkg-cross .deb filename or
converts a dpkg-cross .deb filename into the original .deb filename.

returns undef on error

=cut

sub convert_filename {
	my $name = shift;
	return undef if (!defined($name));
	return undef if ($name !~ /\.deb$/);
	my ($ret, $a);
	my @parts = split (/_/, $name);
	return undef if (!@parts);
	if ($parts[0] =~ /\-([a-z0-9_]+)\-cross$/)
	{
		# return the original name
		$a = $1;
		my $b = $parts[0];
		$b =~ s/\-$a\-cross//;
		return undef if (!defined check_arch($a));
		$ret = $b . "_" . $parts[1] . "_" . $a . ".deb";
	}
	else
	{
		# return the cross name
		return undef if (!defined($parts[2]));
		$a = $parts[2];
		$a =~ s/\.deb//;
		return undef if (!defined check_arch($a));
		my $pkg = $parts[0] . "-${a}-cross";
		$ret = "${pkg}_" . $parts[1] . "_all.deb";
	}
	return $ret;
}

=head1 get_architecture

Returns the current architecture.

return: Current architecture or empty if not set.

=cut

sub get_architecture {
	$debug_data{'default_arch'} = $default_arch;
	$debug_data{'arch'} = $arch;
	$debug_data{'env_arch'} = $ENV{'ARCH'};
	$debug_data{'env_cross_arch'} = $ENV{'DPKGCROSSARCH'};
	return $ENV{'DPKGCROSSARCH'} || $ENV{'ARCH'} || $arch || $default_arch;
}

=head1 check_arch($arch)

Checks that the supplied $arch is (or can be converted to)
a DEB_HOST_GNU_TYPE that can be supported by dpkg-cross.

returns the DPKG_HOST_GNU_TYPE or undef

=cut

sub check_arch {
	my $check = shift;
	my $deb_host_gnu_type;
	chomp($deb_host_gnu_type = `CC="" dpkg-architecture -f -a$check -qDEB_HOST_GNU_TYPE 2> /dev/null`);
	$deb_host_gnu_type ||= $archtable{$check};
	$arch = $check if (defined($deb_host_gnu_type));
	return $deb_host_gnu_type;
}

=head1 setup

Set global variables '$arch', '$crossbase', '$crossbin', '$crosslib32',
'$crossdir', '$crossinc', '$crosslib', '$crosslib64', '$crossprefix',
'$compilerpath' and '$deb_host_gnu_type' to defaults and substitute
them with variables from '%conf' and '$arch'.

return: none

=cut

sub setup {
	my ($var_, $os_, $scope_);
	# Set '$arch' to defaults if not already specified.
	$arch = &get_architecture();
	die "$progname: Architecture is not specified.\n" unless ($arch);
	$deb_host_gnu_type = `CC="" dpkg-architecture -f -a$arch -qDEB_HOST_GNU_TYPE 2> /dev/null`;
	chomp($deb_host_gnu_type);
	$deb_host_gnu_type ||= $archtable{$arch};

	# Finalize, no subst possible crossbase.
	$crossbase ||= "/usr";

	# Set defaults for internal vars, if not set ...
	$crossprefix ||= $ENV{'CROSSPREFIX'} || "${deb_host_gnu_type}-";
	$crossdir ||= "\$(CROSSBASE)/${deb_host_gnu_type}";
	$crossbin ||= "\$(CROSSDIR)/bin";

	if (exists $allcrossroots{$arch}) {
		$crosslib  ||= "\$(CROSSROOT)/lib";
		$crossinc  ||= "\$(CROSSROOT)/usr/include";
		$crossroot = $allcrossroots{$arch};
	}
	else {
		$crosslib  ||= "\$(CROSSDIR)/lib";
		$crossinc  ||= "\$(CROSSDIR)/include";
	}

	$crosslib64 ||= $crosslib . "64";
	$crosslib32 ||= $crosslib . "32";
	$config{'crossbase'} = $crossbase;
	$config{'crossprefix'} = $crossprefix;
	$config{'crossdir'} = $crossdir;
	$config{'crossbin'} = $crossbin;
	$config{'crosslib'} = $crosslib;
	$config{'crosslib64'} = $crosslib64;
	$config{'crosslib32'} = $crosslib32;
	$config{'crossinc'} = $crossinc;
	$config{'crossroot'} = $crossroot;

	# substitute references in the variables.
	foreach my $key (keys %config) {
		next if $key eq "crossbase" or $key eq "maintainer";
		my $val = $config{$key};
		next if (!defined($val));
		$val =~ s/\$\(CROSSDIR\)/$crossdir/;
		$val =~ s/\$\(CROSSBASE\)/$crossbase/;
		$config{$key} = $val;
	}
	# read the evaluated versions
	$crossbase = $config{'crossbase'};
	$crossprefix = $config{'crossprefix'};
	$crossdir = $config{'crossdir'};
	$crossbin = $config{'crossbin'};
	$crosslib = $config{'crosslib'};
	$crosslib64 = $config{'crosslib64'};
	$crosslib32 = $config{'crosslib32'};
	$crossinc = $config{'crossinc'};
}

=head1 create_tmpdir($basename)

Safely create a temporary directory

 $1: Directory basename (random suffix will be added)

return: Full directory pathname, undef if failed

=cut

sub create_tmpdir {
	my $name = shift;
	my $pd = $ENV{'TMPDIR'} && -d $ENV{'TMPDIR'}
		? $ENV{'TMPDIR'}
		: '/tmp';
	return undef unless -d $pd;
	my $dir;

	eval { $dir = tempdir("$name.XXXXXXXX", DIR => $pd) };
	print("$@"), return undef if $@;

	return $dir;
}

=head1 convert_path($path)

Convert path, substituting '$crossinc', '$crosslib', '$crosslib64',
'$crosslib32', '$crossdir'. This function will be used while building foreign
binary packages or converting GCC options.

 $1: Directory (and file) to convert.

return: Converted path.

=cut

sub convert_path {
	my $path = &simplify_path ($_[0]);
	if ($path =~ /^\/usr(\/X11R6)?\/include\//) {
		$path = "$crossinc/$'";
	} elsif ($path =~ /^(\/usr(\/X11R6)?)?\/lib\//) {
		$path = "$crosslib/$'";
	} elsif ($path =~ /^(\/usr(\/X11R6)?)?\/lib64\//) {
		$path = "$crosslib64/$'";
	} elsif ($path =~ /^(\/usr(\/X11R6)?)?\/lib32\//) {
		$path = "$crosslib32/$'";
	} elsif ($path =~ m:^(/emul/ia32-linux/(usr/)?lib/):) {
		$path = "$crosslib32/$'";
	} elsif ($path =~ /^\/usr\/\w+-\w+(-\w+(-\w+)?)?\//) {
		# leave alone
	} else {
		$path =~ s/^\/usr/$crossdir/;
	}
	return $path
}

=head1 simplify_path($path)

Simplify path. Remove duplicate slashes, "./", "dir/..", etc

$1: Path to simplify.

return: Simplified path.

=cut

sub simplify_path {
	my $path = $_[0];
	# This will remove duplicate slashes
	$path =~ s/\/+/\//g;
	# This will remove ./
	while ($path =~ s/(^|\/)\.\//$1/) {}
	$path =~ s/(.)\/\.$/$1/;
	# This will remove /.. at the beginning
	while ($path =~ s/^\/\.\.(.)/$1/) {}
	# Previous REs could keep standalone /. or /..
	$path =~ s/^\/\.(\.)?$/\//;
	# Remove dir/..
	# First split path into leading ../.. (if any) and the rest
	# Then remove XXX/.. substring while it exists in the later part
	my ($pref, $suff);
	if ($path =~ /^(\.\.(\/\.\.)*)(\/.*)$/) {
		($pref, $suff) = ($1, $3);
	} else {
		($pref, $suff) = ("", $path);
	}
	while ($suff =~ s/(^|\/)[^\/]+\/\.\.(\/|$)/$1/) {}
	$path = $pref . $suff;
	# Replace possibly generated empty string by "."
	$path =~ s/^$/./;
	# Remove possible '/' at end
	$path =~ s/([^\/])[\/]$/$1/;

	return $path;
}

=head1 get_endianness

Provide a central function to query the endianness of the
current cross building architecture.

Parses /etc/dpkg-cross/cross-config.$arch to convert the
autotools cache value into a general purpose string.

Returns 'big' or 'little' or undefined on error.

=cut

sub get_endianness
{
	my $cfile = "/etc/dpkg-cross/cross-config.$arch";
	my $endian;
	return $endian if (! -f $cfile);
	my $config = Config::Auto::parse("$cfile", format => "equal");
	return $endian if (not defined ($config->{'ac_cv_c_bigendian'}));
	$endian = ($config->{'ac_cv_c_bigendian'} eq "yes") ? "big" : "little";
	return $endian;
}

=head2 detect_arch

Detect architecture of a given ELF or AR file using 'file' output.
In general case it seems to be impossible to distinguish between
OSes (e.g. between i386-linux and i386-hurd), so just detect
CPU architecture

 $1: Filename to process

return: Detected architecture name on success, empty string on failure

Note that the table used by this routine is incomplete and may not
always identify the arch. Always check the return value.

=cut

sub detect_arch {
	my $file_ = shift (@_);

	my $string_ = `LC_ALL=C file -L "$file_" 2>/dev/null`;
	my $arch_ = $ENV{DPKGCROSSARCH} || $ENV{ARCH};
	return $arch_ if $arch_;

	for $arch_ (keys(%archdetecttable)) {
		my $re_ = $archdetecttable{$arch_};
		if ($string_ =~ /$re_/) {
			if ($arch_ eq "AR") {
				# AR archives look similar for all archs.
				# Extract a file and call detect_arch recursively for it
				$arch_ = "";
				my $obj_ = `ar t "$file_" 2>/dev/null | head -n1`;
				chomp($obj_);	# remove newline
				if ($obj_) {
					my ($fh_, $tmp_) = tempfile(DIR => $ENV{'TMPDIR'} || '/tmp');
					if (system("ar p \"$file_\" \"$obj_\" > $tmp_ 2>/dev/null") == 0) {
						$arch_ = detect_arch($tmp_);
					}
					close $fh_;
					unlink($tmp_);
				}
			}
			return $arch_;
		}
	}
	return "";
}

=head1 Legacy code

The following functions were part of dpkg-cross.pl <= 1.39
and were only used by the dpkg-cross diversions of dpkg-buildpackage
or dpkg-shlibdeps. The functions and the scripts are retained for
now as legacy code or for bespoke implementations but may be removed
at a later date. It is NOT recommended to use these functions for
newly written code. Scripts that do use these functions must import
them explicitly.

=head1 get_keepdeps

Array containing the list of dependencies to be kept when building a
cross package. Read from the $conffile.

Largely superceded by the -X support in dpkg-cross itself.

 Deprecated: May be removed in future versions.

=cut

sub get_keepdeps {
	return @keepdeps;
}

=head1 get_removedeps

Array containing the list of dependencies to be remove when building a
cross package. Read from the $conffile.

Largely superceded by the -X support in dpkg-cross itself.

 Deprecated: May be removed in future versions.

=cut

sub get_removedeps {
	return @removedeps;
}

################################################################################
# read_crosstools_file(): DEPRECATED
#     Reads /etc/dpkg-cross/crosstools or ~/.dpkg-cross/crosstools and saves results
#     in a global hash. Do nothing if file can't be read.
# $1: file to read
my %crosstools; # $crosstools{$arch}{$tool}{$mode}
sub read_crosstools_file {
	my $file_ = shift (@_);

	open (FILE, $file_) or return;
	while (<FILE>) {
		/^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/ && ($crosstools{$1}{$2}{$3} = $4);
	}
	close (FILE);
}

################################################################################
# find_in_path():
#  Internal routine that finds an executable in PATH. A faster version of `which $p`
# $1: what to find
# return: pathname or empty string
sub find_in_path {
	my $p_ = shift (@_);

	return "" if (!$p_);
	for my $dir_ (split (':', $ENV{'PATH'})) {
		return "$dir_/$p_" if (-x "$dir_/$p_");
	}
	return "";
}

=head2 get_tool

Legacy code - only used by the old version of dpkg-shlibdeps
from dpkg-cross <= 1.39

 Finds appropriate tool for ($arch, $tool, $mode)
 $1: architecture wanted
 $2: tool wanted
 $3: current mode
 return: pathname of the tool

=cut

my $crosstools_read = 0;
sub get_tool {
	my ($arch_, $tool_, $mode_) = @_;
	# is $mode needed? is $crosstools needed?
	if (! $crosstools_read) {
		&read_crosstools_file("/etc/dpkg-cross/crosstools");
		&read_crosstools_file($ENV{"HOME"} . "/.dpkg-cross/crosstools");
		$crosstools_read = 1;
	}

	for my $m_ ($mode_, "default") {
		next if not defined($crosstools{$arch_}{$tool_}{$m_});
		my $t_ = $crosstools{$arch_}{$tool_}{$m_};
		return $t_ if ($t_ =~ /^\//);
		$t_ = &find_in_path($t_);
		return $t_ if ($t_);
	}
	my $prefix_ = `CC="" dpkg-architecture -f -a$arch_ -qDEB_HOST_GNU_TYPE 2> /dev/null`;
	if( chomp($prefix_) ) {
		my $t_ = &find_in_path($prefix_ . "-" . $tool_);
		return $t_ if (defined ($t_));
	}
	if (defined($crossprefixtable{$arch_})) {
		my @l_ = @{$crossprefixtable{$arch_}};
		# move $crossprefix to the first place in the list
		@l_ = ((grep {$_ eq $crossprefix} @l_), (grep {$_ ne $crossprefix} @l_));
		for (@l_) {
			my $t_ = &find_in_path($_ . $tool_);
			return $t_ if ($t_);
		}
	}

	return "/usr/bin/$tool_";
};

=head2 setup_cross_env

Legacy code - only used by the old version of dpkg-shlibdeps
from dpkg-cross <= 1.39

This function has since been implemented as a shell "library" -
buildcross that is called directly by the non-diverted
dpkg-buildpackage.

Set the environment variables MAKEFLAGS, PATH, PKG_CONFIG_LIBDIR and all
variables from '%pkgvars' which are marked for scope "environment".

return: none

=cut

sub setup_cross_env {
	my ($var_, $tmp_, $pkghashref, %makeflags_, $setmakeflags_,
	$native_cpu_, $pkg_config_path_);
	$arch = $_[0];
	$mode = $_[1];
	# Read and process config file.
	&read_config;
	&setup;
	# Put '$arch' into environment
	$makeflags_{'ARCH'} = $arch;
	$ENV{'DPKGCROSSARCH'} = $arch;

	# Set `dpkg-architecture' environment variables.
	foreach $var_ qw(DEB_HOST_ARCH DEB_HOST_ARCH_OS DEB_HOST_ARCH_CPU
				DEB_HOST_GNU_CPU DEB_HOST_GNU_SYSTEM DEB_HOST_GNU_TYPE) {
		chomp ($tmp_ = `dpkg-architecture -a$arch -q$var_ 2>/dev/null`);
		$ENV{$var_} = $tmp_;
	}

	# Prepend /usr/share/dpkg-cross/ to PATH to make use of the strip wrapper.
	# Also append $crossbin, so that cross binaries can be found, but
	# native stuff still has precedence (if a package wants to compile
	# with 'gcc' a build tool that will be executed, for example).

	$ENV{'PATH'} = "/usr/share/dpkg-cross:$ENV{PATH}:$crossbin";
	# Save mode for strip wrapper
	$ENV{'DPKGCROSSMODE'} = $mode;

	# Set USRLIBDIR to $(CROSSLIB), for imake-generated Makefiles..
	$makeflags_{'USRLIBDIR'} = $crosslib;

	# Set CONFIG_SITE to /etc/dpkg-cross/cross-config.'$arch', for
	# packages using GNU autoconf configure scripts.
	$makeflags_{'CONFIG_SITE'} = "/etc/dpkg-cross/cross-config.$arch";

	# Set standard variables for compilers and binutils.
	foreach $var_ ( keys %std_tools ) {
		$tool_ = $crossprefix.$std_tools{$var_};
		$makeflags_{$var_} = &find_in_path($tool_) ne "" ? $tool_ : $std_tools{$var_};
	}

	# Allow to use $crossprefix-gcc -E as preprocessor if $crossprefix-cpp
	# is not available
	if ((&find_in_path($makeflags_{"CPP"}) eq "") && (&find_in_path($makeflags_{"GCC"}) ne "")) {
		$makeflags_{"CPP"} = $makeflags_{"IMAKECPP"} = $makeflags_{"GCC"} . "\\ -E";
	}

	$debug_data{'makeflags'} = \%makeflags_;

	if (exists $ENV{'MAKEFLAGS'}) {
		$setmakeflags_ = $ENV{'MAKEFLAGS'};
		$setmakeflags_ .= " -- " if $setmakeflags_ !~ / -- /;
	} else {
		$setmakeflags_ = "w -- ";
	}
	foreach (keys %makeflags_) {
		$setmakeflags_ .= " $_=$makeflags_{$_}";
	}

	$debug_data{'env_makeflags'} = \$setmakeflags_;

	# Add PKG_CONFIG_LIBDIR to enironment, to make `pkg-config' use
	# our directory instead of /usr/lib/pkgconfig.
	$ENV{'PKG_CONFIG_LIBDIR'} = $crosslib . "/pkgconfig";

	# Set additional environment variabled specified in "mode environment:".
	foreach $var_ (keys %{ $pkgvars{'environment'} }) {
		if (ref $pkgvars{'environment'}{$var_}) {
			delete $ENV{$var_};
		} else {
			$ENV{$var_} = $pkgvars{'environment'}{$var_};
		}
	}
}

=head2 dpkgcross_application

Legacy code - only used by the old version of dpkg-shlibdeps
from dpkg-cross <= 1.39

If not called (indirectly) from 'dpkg-buildpackage -a<arch>', then
exec the original.

This function also initialise '$arch' as set by `dpkg-buildpackage -a'.

return: none

=cut

sub dpkgcross_application {
	if ($ENV{'DPKGCROSSARCH'}) {
		$arch = $ENV{'DPKGCROSSARCH'};
		return;
	}
	# Keep this for now for backward-compatibility
	if ($ENV{'ARCH'} && $ENV{'MAKEFLAGS'} =~ /\bCC=/) {
		$arch = $ENV{'ARCH'};
		return;
	}
	exec "$0.orig", @ARGV;
}

=head2 convert_ld_library_path

Legacy code - only used by the old version of dpkg-shlibdeps
and strip from dpkg-cross <= 1.39

Remove from LD_LIBRARY_PATH everything that does not start with /usr/lib
or /usr/share. This is needed to avoid non-native libraries in
LD_LIBRARY_PATH. Just unsetting of LD_LIBRARY_PATH does not work because
of usage of LD_LIBRARY_PATH by fakeroot.

=cut

sub convert_ld_library_path {
	return if (!defined($ENV{'LD_LIBRARY_PATH'}));
	my @list = split(':', $ENV{'LD_LIBRARY_PATH'});
	$ENV{'LD_LIBRARY_PATH'} = join(':', grep {$_ =~ /^\/usr\/(lib|share)\//} @list);
}

1;
