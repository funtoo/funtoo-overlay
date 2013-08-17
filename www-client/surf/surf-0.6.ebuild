# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/www-client/surf/surf-0.6.ebuild,v 1.3 2013/03/31 17:37:17 nimiux Exp $

EAPI=4
inherit savedconfig toolchain-funcs eutils

DESCRIPTION="a simple web browser based on WebKit/GTK+"
HOMEPAGE="http://surf.suckless.org/"
SRC_URI="http://dl.suckless.org/${PN}/${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

DEPEND="
	dev-libs/glib
	net-libs/libsoup
	net-libs/webkit-gtk:2
	x11-libs/gtk+:2
	x11-libs/libX11
"
RDEPEND="
	!sci-chemistry/surf
	!savedconfig? ( net-misc/wget x11-terms/xterm )
	x11-apps/xprop
	x11-misc/dmenu
	${DEPEND}
"

pkg_setup() {
	elog "net-misc/wget and x11-terms/xterm will be installed by default to"
	elog "support the default download command, which can be changed through"
	elog "the savedconfig mechanism. If you enable USE=savedconfig, you will"
	elog "need to satisfy requirements for the alternative download command"
	elog "yourself."
}

src_prepare() {
	epatch_user
	sed -i \
		-e 's|{|(|g;s|}|)|g' \
		-e 's|\t@|\t|g;s|echo|@&|g' \
		-e 's|^LIBS.*|LIBS = $(GTKLIB) -lgthread-2.0|g' \
		-e 's|^LDFLAGS.*|LDFLAGS += $(LIBS)|g' \
		-e 's|^CC.*|CC ?= gcc|g' \
		-e 's|^CFLAGS.*|CFLAGS += -std=c99 -pedantic -Wall $(INCS) $(CPPFLAGS)|g' \
		config.mk Makefile || die "sed failed"
	restore_config config.h
	tc-export CC
}

src_install() {
	emake DESTDIR="${D}" PREFIX="/usr" install
	save_config config.h
}

pkg_postinst() {
	ewarn "Please correct the permissions of your \$HOME/.surf/ directory"
	ewarn "and its contents to no longer be world readable (see bug #404983)"
}
