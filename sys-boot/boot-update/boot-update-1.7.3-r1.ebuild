# Distributed under the terms of the GNU General Public License v2

EAPI="5"

PYTHON_COMPAT=( python2_7 python3_3 )

inherit multilib python-single-r1

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

DEPEND="${PYTHON_DEPS}"
RDEPEND="${DEPEND} >=sys-boot/grub-2.00-r5[binfont]"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

src_unpack() {
	unpack ${A}
	mv "${WORKDIR}/${GITHUB_USER}-${PN}"-??????? "${S}" || die
}

src_install() {
	insinto $(python_get_sitedir)
	cd ${S}/python/modules
	doins -r .

	cd ${S}
	dodoc doc/*.rst

	doman doc/boot-update.8
	doman doc/boot.conf.5

	into /
	dosbin sbin/boot-update
	sed -i -e "1 s:^.*$:#!${PYTHON}:" -e "s:^version = .*$:version = \"${PV}\":" ${D}/sbin/boot-update
	dodoc etc/boot.conf.example
	insinto /etc
	doins etc/boot.conf
	doins etc/boot.conf.defaults
	doins etc/boot.conf.example
}

src_compile() {
	return
}
