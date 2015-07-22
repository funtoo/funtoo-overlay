# Distributed under the terms of the GNU General Public License v2

EAPI=5

DESCRIPTION="Compose is a tool for defining and running complex applications with Docker"
HOMEPAGE="https://docs.docker.com/compose/"
MY_PN="${PN%-bin}"
MY_PV="${PV/_/}"
SRC_URI="
	amd64? ( https://github.com/docker/compose/tree/${MY_PV} -> ${P}-Linux-x86_64 )
"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

DEPEND=""
RDEPEND="${DEPEND}"

RESTRICT="installsources strip"

S="${DISTDIR}"

src_install() {
	newbin ${P}-Linux-x86_64 ${MY_PN}
}
