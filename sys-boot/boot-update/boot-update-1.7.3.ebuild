# Distributed under the terms of the GNU General Public License v2

EAPI="4-python"

PYTHON_MULTIPLE_ABIS="1"
PYTHON_RESTRICTED_ABIS="2.5 3.1 *-jython *-pypy-*"
inherit multilib python

DESCRIPTION="Funtoo Core Boot Framework for global boot loader configuration"
HOMEPAGE="http://www.funtoo.org/Package:Boot-Update"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="*"
RESTRICT="mirror"
GITHUB_REPO="boot-update"
GITHUB_USER="funtoo"
GITHUB_TAG="${PV}"
SRC_URI="https://www.github.com/${GITHUB_USER}/${GITHUB_REPO}/tarball/${GITHUB_TAG} -> boot-update-${GITHUB_TAG}.tar.gz"

IUSE=""

DEPEND=""
RDEPEND=">=sys-boot/grub-2.00-r5[binfont]"

src_unpack() {
	unpack ${A}
	mv "${WORKDIR}/${GITHUB_USER}-${PN}"-??????? "${S}" || die
}

install_into_site_packages() {
	insinto $(python_get_sitedir)
	cd ${S}/python/modules
	doins -r .
}

src_install() {
	python_execute_function install_into_site_packages

	dodoc doc/*.rst

	doman doc/boot-update.8
	doman doc/boot.conf.5

	into /
	dosbin sbin/boot-update

	dodoc etc/boot.conf.example
	insinto /etc
	doins etc/boot.conf
	doins etc/boot.conf.defaults
	doins etc/boot.conf.example
}

src_compile() {
	return
}
