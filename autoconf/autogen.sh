#!/bin/sh -e
#
#  autogen.sh - Helper application of GNU AutoTools
#  Copyright (C) 1997-2000  Roman Hodek <roman@hodek.net>
#  Copyright (C) 2000-2002  Colin Watson <cjwatson@debian.org>
#  Copyright (C) 2002-2004  David Schleef <ds@schleef.org>
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
#  THIS IS AN AUTOMATICALY GENERATED FILE. DON'T MANUALLY MODIFY THIS FILE
#  UNTIL YOU REALLY KNOW WHAT YOU ARE DOING.
#  
#  $Id: autogen.sh,v 1.2 2004/06/21 18:29:27 yoush-guest Exp $

aclocal 
automake --add-missing --foreign --gnu
autoconf

rm -f config.cache

./configure --enable-maintainer-mode $*

