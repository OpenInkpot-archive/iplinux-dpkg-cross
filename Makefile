#
#  Copyright (C) 1997-2000  Roman Hodek <roman@hodek.net>
#  Copyright (C) 2004  Raphael Bossek <bossekr@debian.org>
#  Copyright (c) 2007  Neil Williams <codehelp@debian.org>
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
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#

MAN1 = dpkg-cross.1 gccross.1
MAN5 = cross-compile.5

all: $(MAN1) $(MAN5) man3

test: 

%.1 %.5:	%.sgml
	docbook-to-man $^ > $@

man3: 
	pod2man Debian/DpkgCross.pm > Debian::DpkgCross.3

install:


clean:
	rm -f $(MAN1) $(MAN5)
	-find autoconf/. -not -name "configure.ac" \
			 -not -name "autogen.sh" \
			 -not -name "CVS" \
			 -not -name m4 \
			 -not -name Makefile.am \
			 -maxdepth 1 -exec rm -rf {} \; >/dev/null 2>&1

distclean: clean

