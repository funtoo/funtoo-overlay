# Distributed under the terms of the GNU General Public License v2

EAPI=5

inherit autotools

DESCRIPTION="Pulseaudio Volume Control, GTK based mixer for Pulseaudio"
HOMEPAGE="http://freedesktop.org/software/pulseaudio/pavucontrol/"
SRC_URI="mirror://funtoo/distfiles/${P}.tar.gz"

RESTRICT="mirror"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"
IUSE="nls"
S=$WORKDIR/$PN

RDEPEND="
	>=dev-cpp/gtkmm-3.0:3.0
	>=dev-libs/libsigc++-2.2:2
	>=media-libs/libcanberra-0.16[gtk3]
	>=media-sound/pulseaudio-3[glib]
	virtual/freedesktop-icon-theme
"
DEPEND="${RDEPEND}
	virtual/pkgconfig
	nls? (
		dev-util/intltool
		sys-devel/gettext
		)
"
src_prepare() {
	eautoreconf || die
	touch doc/README || die
}
src_configure() {
	econf \
		--docdir=/usr/share/doc/${PF} \
		--htmldir=/usr/share/doc/${PF}/html \
		--disable-lynx \
		$(use_enable nls)
}
