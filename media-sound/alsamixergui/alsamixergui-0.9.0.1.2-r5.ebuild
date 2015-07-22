# Distributed under the terms of the GNU General Public License v2

EAPI=5
inherit autotools eutils flag-o-matic

MY_P=${PN}-0.9.0rc1-2

DESCRIPTION="FLTK based amixer Frontend"
HOMEPAGE="http://www.gentoo.org/"
SRC_URI="mirror://gentoo/${MY_P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"
IUSE=""

RDEPEND="media-libs/alsa-lib
	media-sound/alsa-utils
	x11-libs/fltk:1"
DEPEND="${RDEPEND}"

S=${WORKDIR}/${MY_P}

DOCS=( AUTHORS ChangeLog README )

src_prepare() {
	epatch "${FILESDIR}"/${PN}-autotools.patch
	epatch "${FILESDIR}"/${PN}-modernfix.patch
	epatch "${FILESDIR}"/segfault-on-exit.patch
	eautoreconf
}

src_install() {
	default
	newicon src/images/alsalogo.xpm ${PN}.xpm
	make_desktop_entry ${PN} "Alsa Mixer GUI"
}
