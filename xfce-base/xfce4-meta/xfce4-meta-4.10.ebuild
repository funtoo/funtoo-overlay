# Distributed under the terms of the GNU General Public License v2

EAPI=5

DESCRIPTION="The Xfce Desktop Environment (meta package)"
HOMEPAGE="http://www.xfce.org/"
SRC_URI=""

LICENSE="metapackage"
SLOT="0"
KEYWORDS="*"
IUSE="minimal mixer ristretto thunar thunar-volman tumbler xfburn terminal +svg"

RDEPEND=">=x11-themes/gtk-engines-xfce-3:0
	x11-themes/hicolor-icon-theme
	>=xfce-base/xfce4-appfinder-4.10
	>=xfce-base/xfce4-panel-4.10
	>=xfce-base/xfce4-session-4.10
	>=xfce-base/xfce4-settings-4.10
	>=xfce-base/xfdesktop-4.10
	>=xfce-base/xfwm4-4.10
	thunar? ( >=xfce-base/xfdesktop-4.10[thunar=] )
	thunar-volman? ( >=xfce-extra/thunar-volman-0.8.0 )
	terminal? ( >=x11-terms/xfce4-terminal-0.6.3 )
	ristretto? ( media-gfx/ristretto )
	tumbler? ( xfce-extra/tumbler )
	mixer? ( xfce-extra/xfce4-mixer )
	xfburn? ( app-cdr/xfburn )
	!minimal? (
		media-fonts/dejavu
		virtual/freedesktop-icon-theme
		)
	svg? ( gnome-base/librsvg )"
