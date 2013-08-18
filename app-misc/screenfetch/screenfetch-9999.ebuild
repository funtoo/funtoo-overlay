# Distributed under the terms of the GNU General Public License v2

EAPI=4

inherit git-2
EGIT_REPO_URI="https://github.com/KittyKatt/screenFetch"

DESCRIPTION="A Bash Screenshot Information Tool"
HOMEPAGE="https://github.com/KittyKatt/screenFetch"

#MY_PN="${PN/f/F}"
#SRC_URI="https://github.com/KittyKatt/${MY_PN}/archive/v${PV}.tar.gz"
#S="${WORKDIR}/${MY_PN}-${PV}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

RDEPEND="media-gfx/scrot
	x11-apps/xdpyinfo"

src_install() {
	dobin ${PN}-dev
	dosym ${PN}-dev /usr/bin/${PN}
	dodoc CHANGELOG README.mkdn TODO
}
