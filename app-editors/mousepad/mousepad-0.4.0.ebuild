EAPI=5
inherit xfconf

DESCRIPTION="GTK+ based editor for the Xfce Desktop Environment"
HOMEPAGE="http://goodies.xfce.org/projects/applications/start"
SRC_URI="mirror://xfce/src/apps/${PN}/${PV%.*}/${P}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE="debug dbus gtk3"

RDEPEND=">=dev-libs/glib-2.30
	<x11-libs/gtk+-3.0.0
	>=x11-libs/gtksourceview-3.0.0
	gtk3? ( >=x11-libs/gtk+-3.0.0 )
	dbus? ( >=dev-libs/dbus-glib-0.100 )"
DEPEND="${RDEPEND}
	dev-lang/perl
	dev-util/intltool
	sys-devel/gettext
	virtual/pkgconfig"
src_configure() {
	econf \
	    $( use_enable gtk3 ) \
	    $( use_enable dbus ) \
            $( use_enable debug )
}

pkg_setup() {
	XFCONF=(
		$(xfconf_use_debug)
		$(use_enable dbus)
		)

	DOCS=( AUTHORS ChangeLog NEWS README TODO )
}
