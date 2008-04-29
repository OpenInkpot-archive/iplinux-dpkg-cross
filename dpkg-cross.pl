#
#  dpkg-cross.pl - Package with dpkg-cross common used functions
#  Copyright (C) 2004  Nikita Youshchenko <yoush@cs.msu.su>
#  Copyright (C) 2004  Raphael Bossek <bossekr@debian.org>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#  $Id: dpkg-cross.pl,v 1.42 2006/10/15 11:17:32 yoush Exp $

use File::Temp qw/tempfile tempdir/;

# Determine if the system wide or user defined cross-compile configuration
# have to be read.
$conffile = "/etc/dpkg-cross/cross-compile";
$private_conffile = "$ENV{'HOME'}/.dpkg-cross/cross-compile";
$conffile = (-e $private_conffile) ? $private_conffile : $conffile;

# Name of the calling application.
($progname = $0) =~ s,.*/,,;

# List of variables which can be overriden by the cross-compile
# definitions.
@intern_vars = qw( crossbase crossprefix crossdir crossbin crosslib crosslib64 crossinc
		maintainer default_arch removedeps keepdeps compilerpath );
# Avoid warnings about unused @intern_vars variables.
foreach my $var_ ( @intern_vars ) {
	eval( "\$$var_ = ''" );
}

# Version of dpkg-cross environment.
$DPKGCROSSVERSION = "1.32";

# Convertion table for Debian GNU/Linux architecture name (``$arch'') to GNU
# type.
%archtable = (
	'i386' => 'i486-linux-gnu',
	'uclibc-i386' => 'i486-linux-uclibc',
	'sparc' => 'sparc-linux-gnu',
	'sparc64' => 'sparc-linux-gnu',
	'alpha' => 'alpha-linux-gnu',
	'm68k' => 'm68k-linux-gnu',
	'arm' => 'arm-linux-gnu',
	'armeb' => 'armeb-linux-gnu',
	'armel' => 'arm-linux-gnueabi',
	'uclibc-arm' => 'arm-linux-uclibc',
	'powerpc' => 'powerpc-linux-gnu',
	'uclibc-powerpc' => 'powerpc-linux-uclibc',
	'ppc' => 'powerpc-linux-gnu',
	'mips' => 'mips-linux-gnu',
	'uclibc-mips' => 'mips-linux-uclibc',
	'mipsel' => 'mipsel-linux-gnu',
	'uclibc-mipsel' => 'mipsel-linux-uclibc',
	'sh3' => 'sh3-linux-gnu',
	'sh4' => 'sh4-linux-gnu',
	'sh4a' => 'sh4a-linux-gnu',
	'uclibc-sh4' => 'sh4-linux-uclibc',
	'uclibc-sh4a' => 'sh4a-linux-uclibc',
	'sh3eb' => 'sh3eb-linux-gnu',
	'sh4eb' => 'sh4eb-linux-gnu',
	'uclibc-sh4eb' => 'sh4eb-linux-uclibc',
	'hppa' => 'hppa-linux-gnu',
	'hurd-i386' => 'i386-gnu',
	's390' => 's390-linux-gnu',
	's390x' => 's390-linux-gnu',
	'ia64' => 'ia64-linux-gnu',
 	'm32r' => 'm32r-linux-gnu',
	'openbsd-i386' => 'i386-openbsd',
	'freebsd-i386' => 'i386-freebsd',
	'darwin-powerpc' => 'powerpc-darwin',
	'darwin-i386' => 'i386-darwin',
	'win32-i386' => 'i386-cygwin',
	'amd64' => 'x86_64-linux-gnu');

# Regexps to parse 'file' output to detect arch of ELF binary
# Note that it is not always possibe to restore Debian architecture
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
	'arm' => 'ELF 32-bit LSB .* ARM, version 1 \(ARM\)',
	'armeb' => 'ELF 32-bit MSB .* ARM',
	'armel' => 'ELF 32-bit LSB .* ARM, version 1 \(SYSV\)',
	'powerpc' => 'ELF 32-bit MSB .* PowerPC',
	'powerpc64' => 'ELF 64-bit MSB .* PowerPC',
	'mips' => 'ELF 32-bit MSB .* MIPS',
	'mipsel' => 'ELF 32-bit LSB .* MIPS',
	'sh4' => 'ELF 32-bit LSB .* Hitachi SH',
	'sh4eb' => 'ELF 32-bit MSB .* Hitachi SH',
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
	"uclibc-i386" => [ "i486-linux-uclibc-", "i386-linux-uclibc-" ],
	"sparc" => [ "sparc-linux-gnu-", "sparc-linux-", "sparc64-linux-gnu-", "sparc64-linux-" ],
	"sparc64" => [ "sparc64-linux-gnu", "sparc64-linux-", "sparc-linux-gnu-", "sparc-linux-" ],
	"alpha" => [ "alpha-linux-gnu-", "alpha-linux-" ],
	"m68k" => [ "m68k-linux-gnu-", "m68k-linux-" ],
	"arm" => [ "arm-linux-gnu-", "arm-linux-" ],
	"armeb" => [ "armeb-linux-gnu-", "armeb-linux-" ],
	"armel" => [ "arm-linux-gnueabi-" ],
	"uclibc-arm" => [ "arm-linux-uclibc-" ],
	"powerpc" => [ "powerpc-linux-gnu-", "powerpc-linux-", "ppc-linux-gnu-", "ppc-linux-" ],
	"uclibc-powerpc" => [ "powerpc-linux-uclibc-", "ppc-linux-uclibc-" ],
	"powerpc64" => [ "powerpc64-linux-gnu-", "powerpc64-linux-", "ppc64-linux-gnu-", "ppc64-linux-",
			 "powerpc-linux-gnu-", "powerpc-linux-", "ppc-linux-gnu-", "ppc-linux-" ],
	"mips" => [ "mips-linux-gnu-", "mips-linux-", "mips64-linux-gnu-", "mips64-linux-" ],
	"uclibc-mips" => [ "mips-linux-uclibc-", "mips64-linux-uclibc-" ],
	"mipsel" => [ "mipsel-linux-gnu-", "mipsel-linux-", "mips64el-linux-gnu-", "mips64el-linux-" ],
	"uclibc-mipsel" => [ "mipsel-linux-uclibc-", "mips64el-linux-uclibc-" ],
	"sh4" => [ "sh4-linux-gnu-", "sh4-linux-" ],
	"sh4a" => [ "sh4a-linux-gnu-" ],
	"sh4eb" => [ "sh4eb-linux-gnu-", "sh4eb-linux-" ],
	"uclibc-sh4" => [ "sh4-linux-uclibc-", "sh4-linux-" ],
	"uclibc-sh4a" => [ "sh4a-linux-uclibc-" ],
	"uclibc-sh4eb" => [ "sh4eb-linux-uclibc-" ],
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
%std_tools = (
	CC => "gcc",
	GCC => "gcc",
	CXX => "g++",
	CPP => "cpp",
	IMAKECPP => "cpp",
	AS => "as",
	LD => "ld",
	AR => "ar",
	NM => "nm",
	RANLIB => "ranlib",
	RC => "windres");

# Contains variable definitions from ``$conffile'' distinguished by their
# scope ("makeflags" or "environment") of definition.
# Scope is the first key of ``%pkgvars''. Variable definitions are stored
# as a second hash table. A seperate hash table for each scope. Those hash
# tables contains for their own key,value pairs corresponds to variable
# name and variable value definitions in the specific scope.
%pkgvars = (
	"makeflags" => (),
	"environment" => ());

# Contains ``$crossroot'' definitions by ``$arch'' readed from configuration.
# ``$crossroot'' is set by setup() if ``$arch'' is known from this hash table.
%allcrossroots = ();

################################################################################
# read_config():
#     Read ``$conffile'' and save the definition in global variables for those
#     which are listed in ``@intern_vars'' until first package, mode or scope
#     definition is found.
#
#     ``$crossroot'' will be set by setup(). Until setup() is called all
#     "crossroot-<arch>" settings are stored within ``%allcrossroots''.
#
#     Package's variables are stored within ``%pkgvars''. Only variables from
#     packages "all" and "$1" are set. Those are distinguished between
#     "makeflags" and "environment" scope.
#
#     All other variable are skipped.
# $1: Package name to read configuration for (including special package "all").
# $2: Mode as specified with `dpkg-buildpackage -M<mode>` to read configuration
#     for.
# return: none
sub read_config {
	my ($current_package_, $current_mode_) = @_;	# ok to be undefined
	my ($package_, $mode_, $scope_, $var_, $val_) = ("", "", "", "", "");
	
	$current_mode_ ||= "default";
	
	open (F, "<$conffile") || return;
	while (<F>) {
		chomp;
		s/^\s+//; s/(\s*#.*)?\s*$//;
		next if /^$/;
		
		if (/([\w\d_-]+)\s*=\s*(.*)$/) {
			($var_, $val_) = ($1, $2);
			# dpkg-cross come before any mode, package or scope declarations.
			if (!$package_ && !$mode_ && !$scope_) {
				if ($var_ =~ /^crossroot-(\S+)$/) {
					# We set ``$crossroot'' after we know which ``$arch'' to use.
					# Until then we save the architecture and value for use by setup().
					$allcrossroots{$1} = $val_;
				}
				# Set only variables which are listed in ``@intern_vars''.
				elsif (grep $_ eq $var_, @intern_vars) {
					eval "\$$var_ = '$val_'";
				}
				else {
					warn "$progname: Definition of unknown variable ".
						 "$var_ in $conffile, line $..\n";
				}
				next;
			}

			$package_ ||= "all";
			$mode_ ||= "all";
			$scope_ ||= "makeflags";

			# Store only data for current package and current mode, and
			# for package "all" and mode "all".
			if (($package_ eq "all" || $package_ eq $current_package_) && \
				($mode_ eq "all" || $mode_ eq $current_mode_)) {
				$pkgvars{$scope_}{$var_} = $val_;
			}
		}
		elsif (/^unset\s+([\w\d_-]+)$/) {
			$var_ = $1;
			
			$package_ ||= "all";
			$mode_ ||= "all";
			$scope_ ||= "makeflags";

			if (($package_ eq "all" || $package_ eq $current_package_) && \
				($mode_ eq "all" || $mode_ eq $current_mode_)) {
				$pkgvars{$scope_}{$var_} = {}; # Use a reference as "unset" value
			}
		}
		elsif (/^(package)?\s*?(\S+)\s*:$/i) {
			$package_ = $2;
		}
		elsif (/^mode\s*(\S+)\s*:$/i) {
			$mode_ = $1;
		}
		elsif (/^scope\s*(makeflags|environment)\s*:$/) {
			$scope_ = $1;
		}
		else {
			warn "$progname: Unrecognized line in $conffile, line $..\n";
		}
	}
	close (F);
}

################################################################################
# get_architecture():
#     Returns the current architecture.
# return: Current architecture or empty if not set.
sub get_architecture {
       return $ENV{'DPKGCROSSARCH'} || $ENV{'ARCH'} || $arch || $default_arch;
}


################################################################################
# setup():
#     Set global variables ``$arch'', ``$crossbase'', ``$crossbin'',
#     ``$crossdir'', ``$crossinc'', ``$crosslib'', ``$crosslib64'', ``$crossprefix'',
#     ``$compilerpath'' and ``$deb_host_gnu_type'' to
#     defaults and substitude them with variables from ``@intern_vars'' and
#     ``$arch''.
#
#     All variable definitions from ``%pkgvars'' are also substituded with
#     ``@intern_vars'' and ``$arch''.
# return: none
sub setup {
	my ($var_, $os_, $scope_);
	my @vars_ = ("arch", @intern_vars);
	
	# Set ``$arch'' to defaults if not already specified.
	$arch = get_architecture();
	die "$progname: Architecture is not specified.\n" unless ($arch);
	$deb_host_gnu_type = $archtable{$arch};		# FIXME: should use dpkg-architecture here
	
	# Finalize, no subst possible crossbase.
	$crossbase ||= "/usr";
	
	# Set defaults for internal vars, if not set ...
	$crossprefix   ||= $ENV{'CROSSPREFIX'} || "${deb_host_gnu_type}-";
	$crossdir      ||= "\$(CROSSBASE)/${deb_host_gnu_type}";
	$crossbin      ||= "\$(CROSSDIR)/bin";
	
	if (exists $allcrossroots{$arch}) {
		$crosslib  ||= "\$(CROSSROOT)/lib";
		$crossinc  ||= "\$(CROSSROOT)/usr/include";
		$crossroot = $allcrossroots{$arch};
		push (@vars_, "crossroot");
	}
	else {
		$crosslib  ||= "\$(CROSSDIR)/lib";
		$crossinc  ||= "\$(CROSSDIR)/include";
	}

	$crosslib64 ||= $crosslib . "64";

	# ... and substitute references in them.
	foreach $var_ (@intern_vars) {
		next if $var_ eq "crossbase" || $var_ eq "maintainer";
		subst (eval "\\\$$var_", $var_, @vars_);
	}
	
	# Substitute variable references in package variable definitions.
	foreach $scope_ (keys %pkgvars) {
		foreach $var_ (keys %{$pkgvars{$scope_}}) {
			subst (\$pkgvars{$scope_}{$var_}, $var_, @vars_);
		}
	}
}

################################################################################
# subst():
#     Substitute strings in form $(NAME) by same named global Perl variable
#     (only if variable's name is listed in $3) or by the correspondig
#     envrionment variable. A variable name to substitude which is not defined
#     will by replaced by an empty string.
# $1: Reference to the string should be substituted in place.
# $2: Name of the Perl variable for which the content should be substituded. Is
#     used for warning notifications in case of $(NAME) can not be substitued.
# $3: List of variable names which are allowed to be substituded.
# return: none
sub subst {
	my $valref_ = shift (@_);
	my $varname_ = shift (@_);
	my @defined_vars_ = @_;
	my ($name_, $newval_);

	return if ref $$_valref_;	# skip "unset" values
	
	while ($$valref_ =~ /\$\((\w+)\)/) {
		$name_ = $1;
		if (grep "\U$_\E" eq $name_, @defined_vars_) {
			$newval_ = eval "\"\$\L$name_\E\"";
		}
		elsif (exists $ENV{$name_}) {
			$newval_ = $ENV{$name_};
		}
		else {
			warn "$progname: Cannot substitute \$($name_) in definition ".
				 "of $varname_.\n";
			$newval_ = "";
		}
		$$valref_ =~ s/\$\($name_\)/$newval_/;
	}
}

################################################################################
# detect_arch():
#     Detect architecture of a given ELF or AR file using 'file' output.
#     In general case it seems to be impossible to distinguish between
#     OSes (e.g. between i386-linux and i386-hurd), so just detect
#     CPU architecture
# $1: Filename to process
# return: Detected architecture name on success, empty string on failure
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

################################################################################
# read_crosstools_file():
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
#     Finds an executable in PATH. A faster version of `which $p`
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

################################################################################
# get_tool():
#     Finds appropriate tool for ($arch, $tool, $mode)
# $1: architecture wanted
# $2: tool wanted
# $3: current mode
# return: pathname of the tool
my $crosstools_read = 0;
sub get_tool {
	my ($arch_, $tool_, $mode_) = @_;

	if (! $crosstools_read) {
		read_crosstools_file("/etc/dpkg-cross/crosstools");
		read_crosstools_file($ENV{"HOME"} . "/.dpkg-cross/crosstools");
		$crosstools_read = 1;
	}

	for my $m_ ($mode_, "default") {
		next if not defined($crosstools{$arch_}{$tool_}{$m_});
		my $t_ = $crosstools{$arch_}{$tool_}{$m_};
		return $t_ if ($t_ =~ /^\//);
		$t_ = find_in_path($t_);
		return $t_ if ($t_);
	}

	if (defined($crossprefixtable{$arch_})) {
		my @l_ = @{$crossprefixtable{$arch_}};
		# move $crossprefix to the first place in the list
		@l_ = ((grep {$_ eq $crossprefix} @l_), (grep {$_ ne $crossprefix} @l_));
		for (@l_) {
			my $t_ = find_in_path($_ . $tool_);
			return $t_ if ($t_);
		}
	}

	return "/usr/bin/$tool_";
};


################################################################################
# setup_cross_env():
#     Set the environment variables MAKEFLAGS, PATH, PKG_CONFIG_LIBDIR and all
#     variables from ``%pkgvars'' which are makred for scope "environment".
# return: none
sub setup_cross_env {
	my ($var_, $tmp_, $pkghashref, %makeflags_, $setmakeflags_, $native_cpu_, $pkg_config_path_);
	
	# Read and process config file.
	read_config ($package, $mode);
	setup();
	
	# Put ``$arch'' into environment
	$makeflags_{'ARCH'} = $arch;
	$ENV{'DPKGCROSSARCH'} = $arch;
	
	# Set `dpkg-architecture' environment veriables.
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
	
	# Set CONFIG_SITE to /etc/dpkg-cross/cross-config.``$arch'', for
	# packages using GNU autoconf configure scripts.
	$makeflags_{'CONFIG_SITE'} = "/etc/dpkg-cross/cross-config.$arch";
	
	# Set standard variables for compilers and binutils.
	foreach $var_ ( keys %std_tools ) {
		$tool_ = $crossprefix.$std_tools{$var_};
		$makeflags_{$var_} = find_in_path($tool_) ne "" ? $tool_ : $std_tools{$var_};
	}

	# Allow to use $crossprefix-gcc -E as preprocessor if $crossprefix-cpp
	# is not available
	if ((find_in_path($makeflags_{"CPP"}) eq "") && (find_in_path($makeflags_{"GCC"}) ne "")) {
		$makeflags_{"CPP"} = $makeflags_{"IMAKECPP"} = $makeflags_{"GCC"} . "\\ -E";
	}
	
	# Set additional variables specified in "scope makeflags:" for the current
	# package.
	foreach $var_ ( keys %{ $pkgvars{'makeflags'} } ) {
		if (ref $pkgvars{'makeflags'}{$var_}) {
			delete $makeflags_{$var_};
		} else {
			$makeflags_{$var_} = $pkgvars{'makeflags'}{$var_};
		}
	}
	
	if (exists $ENV{'MAKEFLAGS'}) {
		$setmakeflags_ = $ENV{'MAKEFLAGS'};
		$setmakeflags_ .= " -- " if $setmakeflags_ !~ / -- /;
	} else {
		$setmakeflags_ = "w -- ";
	}
	foreach (keys %makeflags_) {
		$setmakeflags_ .= " $_=$makeflags_{$_}";
	}
	$ENV{'MAKEFLAGS'} = $setmakeflags_;
	
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

################################################################################
# dpkgcross_application():
#     If not called (indirectly) from 'dpkg-buildpackage -a<arch>', then exec
#     the original.
#     This function also initialise ``$arch'' as set by `dpkg-buildpackage -a'.
# return: none
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

################################################################################
# simplify_path():
#     Simplify path. Remove duplicate slashes, "./", "dir/..", etc
# $1: Path to simplify.
# return: Simplified path.
sub simplify_path ($) {
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

################################################################################
# convert_path():
#     Convert path, substituting ``$crossinc'', ``$crosslib'', ``$crosslib64'',
#     ``$crossdir''.
#     This function will be used while building foreign binary packages or
#     converting GCC options.
# $1: Directory (and file) to convert.
# return: Converted path.
sub convert_path ($) {
	my $path = simplify_path ($_[0]);
	if ($path =~ /^\/usr(\/X11R6)?\/include\//) {
		$path = "$crossinc/$'";
	} elsif ($path =~ /^(\/usr(\/X11R6)?)?\/lib\//) {
		$path = "$crosslib/$'";
	} elsif ($path =~ /^(\/usr(\/X11R6)?)?\/lib64\//) {
		$path = "$crosslib64/$'";
	}
	return $path
}

################################################################################
# convert_ld_library_path():
#     Remove from LD_LIBRARY_PATH everything that does not start with /usr/lib
#     or /usr/share. This is needed to avoid non-native libraries in
#     LD_LIBRARY_PATH. Just unsetting of LD_LIBRARY_PATH does not work because
#     of usage of LD_LIBRARY_PATH by fakeroot.
sub convert_ld_library_path () {
	my @list = split(':', $ENV{'LD_LIBRARY_PATH'});
	$ENV{'LD_LIBRARY_PATH'} = join(':', grep {$_ =~ /^\/usr\/(lib|share)\//} @list);
}

################################################################################
# create_tmpdir():
#     Safely create a temporary directory
# $1: Directory basename (random suffix will be added)
# return: Full directory pathname, undef if failed
sub create_tmpdir ($) {
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

1;
