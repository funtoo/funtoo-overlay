# Distributed under the terms of the GNU General Public License v2

EAPI=5
inherit eutils cmake-utils

DESCRIPTION="LXQt common resources"
HOMEPAGE="http://lxqt.org/"

if [[ ${PV} = *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="git://git.lxde.org/git/lxde/${PN}.git"
else
	SRC_URI="http://downloads.lxqt.org/lxqt/${PV}/${P}.tar.xz"
	KEYWORDS="~*"
fi

LICENSE="LGPL-2.1+"
SLOT="0"

DEPEND=">=lxqt-base/liblxqt-0.9.0"
RDEPEND="${DEPEND}"
PDEPEND=">=lxqt-base/lxqt-session-0.9.0"

src_prepare() {
	epatch  "${FILESDIR}"/${P}-theme.patch
}

src_install() {
	cmake-utils_src_install
	dodir "/etc/X11/Sessions"
	dosym  "/usr/bin/startlxqt" "/etc/X11/Sessions/lxqt"
}
