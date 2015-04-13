EAPI="5"

RESTRICT="mirror"
DESCRIPTION="Themes for Gnome Shell Metacity and Gtk-2.0 Gtk-3.0"
HOMEPAGE="http://tiheum.deviantart.com/art/GTK3-Gnome-Shell-Faience-255097456"
SRC_URI="mirror://funtoo/distfiles/gtk3_gnome_shell___faience_by_tiheum-d47vmgg.zip"

LICENSE="as-is"
SLOT="0"
KEYWORDS="~*"
IUSE="gnome-shell"

RDEPEND=">=x11-libs/gtk+-2.10:2
	>=x11-libs/gtk+-3.6:3
	>=x11-themes/gnome-themes-standard-3.6
	>=x11-themes/gtk-engines-unico-1.0.2
	>=x11-themes/gtk-engines-murrine-0.98.1.1
	gnome-shell? ( >=gnome-base/gnome-shell-3.4
			   media-fonts/ubuntu-font-family )"
DEPEND="app-arch/unzip"

# INSTALL file contains useful information for the end user
DOCS=( AUTHORS ChangeLog )

src_unpack() {
	mkdir "${S}"
	cd "${S}"
	unpack "${A}"
}

src_install() {
	insinto /usr/share/themes
	doins -r Faience
	doins -r Faience-* || die "Cannot install Faience extra themes"
}
