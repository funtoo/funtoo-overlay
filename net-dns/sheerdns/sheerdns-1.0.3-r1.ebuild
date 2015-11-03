# Distributed under the terms of the GNU General Public License v2

EAPI="5"

inherit eutils toolchain-funcs multilib

DESCRIPTION="Sheerdns is a small, simple, fast master only DNS server"
HOMEPAGE="http://threading.2038bug.com/sheerdns/"
SRC_URI="http://threading.2038bug.com/sheerdns/${P}.tar.gz"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 ~ppc x86"
IUSE=""
DEPEND=""

S="${WORKDIR}/${PN}"

src_prepare() {
	epatch ${FILESDIR}/${PN}-1.0.3-default-zone.patch
	epatch ${FILESDIR}/${PN}-1.0.3-build-fixes.patch
	sed -i -e "/^CFLAGS=/d" Makefile
}

src_compile() {
	emake CC=$(tc-getCC) || die
}

src_install() {
	dodoc ChangeLog
	doman sheerdns.8
	dosbin sheerdns sheerdnshash
	newinitd ${FILESDIR}/sheerdns.initd sheerdns
	newconfd ${FILESDIR}/sheerdns.confd sheerdns
}
