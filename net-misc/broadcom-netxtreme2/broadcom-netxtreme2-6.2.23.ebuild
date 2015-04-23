# Distributed under the terms of the GNU General Public License v2

EAPI=4

inherit linux-info

DESCRIPTION="Broadcom's NetXtremeII (bnx2 and bnx2x) Gigabit and 10GBe drivers"
HOMEPAGE="http://www.broadcom.com/support/ethernet_nic/netxtremeii.php"
SRC_URI="mirror://funtoo/distfiles/broadcom-linux-${PV}.zip"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE=""

DEPEND="app-arch/unzip"
RDEPEND="${DEPEND}"
S="${WORKDIR}/netxtreme2-${PV}"

src_unpack() {
	unpack ${A}
	cd ${WORKDIR}; tar xf ${WORKDIR}/Server/Linux/Driver/netxtreme2-${PV}.tar.gz || die
}

src_compile() {
	unset ARCH; cd ${S}; make KVER="$KV_FULL" || die
}

src_install() {
	insinto /lib/modules/$KV_FULL/kernel/drivers/net
	for x in bnx2 bnx2x
	do
		strip --strip-debug $x/src/$x.ko
		doins $x/src/$x.ko
		doman $x/src/$x.4
	done
	doins bnx2i/driver/bnx2i.ko
}
