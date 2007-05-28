#
#  Copyright (C) 1997-2000  Roman Hodek <roman@hodek.net>
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
#  $Id: Makefile,v 1.15 2005/12/01 09:40:49 yoush-guest Exp $

SCRIPTS = dpkg-cross dpkg-buildpackage dpkg-shlibdeps dpkg-checkbuilddeps
SHARESCRIPTS = gccross strip objdump objcopy
CONFFILES = $(shell ls -1 cross-config.*) crosstools
MAN1 = dpkg-cross.1 gccross.1
MAN5 = cross-compile.5
DESTDIR =
INSTALL = install

all: $(MAN1) $(MAN5)

%.1 %.5:	%.sgml
	docbook-to-man $^ > $@

install:
	$(INSTALL) -m755 -o root -g root -d $(DESTDIR)/etc/dpkg-cross $(DESTDIR)/usr/bin $(DESTDIR)/usr/share/man/man1 $(DESTDIR)/usr/share/man/man5 $(DESTDIR)/usr/share/perl5 $(DESTDIR)/usr/share/dpkg-cross
	$(INSTALL) -m644 -o root -g root cross-compile.example $(DESTDIR)/etc/dpkg-cross/cross-compile
	$(INSTALL) -m644 -o root -g root $(CONFFILES) $(DESTDIR)/etc/dpkg-cross/
	$(INSTALL) -m755 -o root -g root $(SCRIPTS) $(DESTDIR)/usr/bin/
	$(INSTALL) -m755 -o root -g root $(SHARESCRIPTS) $(DESTDIR)/usr/share/dpkg-cross/
	$(INSTALL) -m644 -o root -g root  $(MAN1) $(DESTDIR)/usr/share/man/man1/
	$(INSTALL) -m644 -o root -g root $(MAN5) $(DESTDIR)/usr/share/man/man5/
	$(INSTALL) -m644 -o root -g root dpkg-cross.pl $(DESTDIR)/usr/share/perl5/

clean:
	rm -f $(MAN1) $(MAN5)
	-find autoconf/. -not -name "configure.ac" \
			 -not -name "autogen.sh" \
			 -not -name "CVS" \
			 -not -name m4 \
			 -not -name Makefile.am \
			 -maxdepth 1 -exec rm -rf {} \; >/dev/null 2>&1

