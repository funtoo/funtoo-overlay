# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/x11-wm/i3/i3-4.0.ebuild,v 1.1 2011/08/01 06:17:07 xarthisius Exp $

EAPI=4

inherit base versionator toolchain-funcs

DESCRIPTION="An improved dynamic tiling window manager"
HOMEPAGE="http://i3wm.org/"
SRC_URI="http://i3wm.org/downloads/${P}.tar.bz2"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

CDEPEND="dev-libs/libev
	dev-libs/yajl
	x11-libs/libxcb
	x11-libs/libX11
	x11-libs/xcb-util"
DEPEND="${CDEPEND}
	dev-util/pkgconfig
	sys-devel/flex
	sys-devel/bison
	x11-proto/xcb-proto"
RDEPEND="${CDEPEND}
	dev-perl/AnyEvent-I3
	dev-perl/IPC-Run
	dev-perl/Try-Tiny
	virtual/perl-Getopt-Long
	x11-apps/xmessage"

DOCS=( GOALS TODO RELEASE-NOTES-${PV} )
PATCHES=( "${FILESDIR}"/${P}-gentoo.diff )

pkg_setup() {
	tc-export CC
	ewarn "${PN} uses x11-terms/rxvt-unicode as a default terminal."
	ewarn "If you wish to use another one merge ${PN} with:"
	ewarn "	TERM_EMU=<YOUR_TERM> emerge ${PN}"
	ewarn "e.g. TERM_EMU=xterm"
}

src_prepare() {
	base_src_prepare
	sed -i -e "/echo \"/d" \
		i3{bar,-config-wizard,-input,-msg,-nagbar}/Makefile || die
}

src_install() {
	base_src_install
	dohtml -r docs/*
}

pkg_postinst() {
	elog "${PN} uses x11-terms/rxvt-unicode as a default terminal."
	elog "Either merge it yourself or change proper bind in"
	elog "/etc/${PN}/config or ~/.${PN}/config"
}
