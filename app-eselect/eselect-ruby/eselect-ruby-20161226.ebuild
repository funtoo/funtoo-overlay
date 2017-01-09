# Distributed under the terms of the GNU General Public License v2

DESCRIPTION="Manages multiple Ruby versions"
HOMEPAGE="http://www.gentoo.org"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"
IUSE=""

RDEPEND=">=app-admin/eselect-1.0.2"

src_install() {
	insinto /usr/share/eselect/modules
	newins "${FILESDIR}/ruby.eselect-${PVR}" ruby.eselect || die
}
