# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="2"

EGIT_REPO_URI="git://code.stapelberg.de/i3"
EGIT_BRANCH="master"

inherit git multilib

DESCRIPTION="An improved dynamic tiling window manager"
HOMEPAGE="http://i3.zekjur.net/"
SRC_URI=""

LICENSE="BSD"
SLOT="0"
KEYWORDS=""
IUSE="debug doc"

RDEPEND=">=x11-libs/libxcb-1.1.93
	>=x11-libs/xcb-util-0.3.3
	x11-libs/libX11
	dev-libs/libev
	dev-libs/yajl"
DEPEND="${RDEPEND}
	>=x11-proto/xcb-proto-1.3
	>=app-text/asciidoc-8.3
	app-text/xmlto
	app-text/docbook-xml-dtd
	sys-devel/bison
	sys-devel/flex"

src_prepare() {
	#epatch "${FILESDIR}"/0001-Remove-_NET_WORKAREA-to-allow-qt-4.6.0-display-menus.patch
	use debug || { sed -i -e "s:DEBUG=1:DEBUG=0:" common.mk || die "sed die - debug" ; }
	sed -i \
		-e "s:/usr/local/include:/usr/include:" \
		-e "s:/usr/local/lib:/usr/$(get_libdir):" \
		common.mk || die "sed die"
}

src_compile() {
	emake || die "emake compile die"
	emake -C man || die "emake man die"
	use doc && { emake -C docs || die "emake docs die" ; }
}

src_install() {
	emake DESTDIR="${D}" install || die "emake install die"
	dodoc GOALS TODO CMDMODE || die "dodoc die"
	doman man/*.1 || die "doman die"
	if use doc; then
		dohtml -r docs/*.html || die "dohtml die"
		elog "Documentation in html is in /etc/share/doc/${P}"
	fi
}
