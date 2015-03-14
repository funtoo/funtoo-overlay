# Distributed under the terms of the GNU General Public License v2

EAPI="5"

inherit eutils

MY_PN="${PN/funtoo/gentoo}"

DESCRIPTION="Funtoo specific zsh completion support (includes emerge and ebuild commands)"
HOMEPAGE="https://github.com/radhermit/gentoo-zsh-completions"
SRC_URI="https://github.com/radhermit/${MY_PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="ZSH"
SLOT="0"
KEYWORDS="*"

RDEPEND="!app-shells/gentoo-zsh-completions
	>=app-shells/zsh-4.3.5"

S="${WORKDIR}/${MY_PN}-${PV}"

src_prepare() {
	epatch "${FILESDIR}/${P}-eselect.patch"
}

src_install() {
	insinto /usr/share/zsh/site-functions
	doins src/_*

	dodoc AUTHORS
}
