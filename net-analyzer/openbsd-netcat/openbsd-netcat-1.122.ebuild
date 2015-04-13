# Distributed under the terms of the GNU General Public License v2

EAPI="5"

inherit eutils toolchain-funcs

DESCRIPTION="OpenBSD rewrite of netcat, including support for IPv6, proxies, and Unix sockets"
HOMEPAGE="http://openbsd.cs.toronto.edu/cgi-bin/cvsweb/src/usr.bin/nc/"
SRC_URI="mirror://funtoo/distfiles/${PN}/${P}.tar.xz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~*"
IUSE=""

DEPEND="
	!net-analyzer/gnu-netcat
	!net-analyzer/netcat
	!net-analyzer/netcat6

	dev-libs/libbsd
	sys-libs/glibc
"
RDEPEND="${DEPEND}"

RESTRICT="mirror"

S="${WORKDIR}"

src_prepare() {
	EPATCH_SOURCE="${FILESDIR}" EPATCH_SUFFIX="patch" EPATCH_FORCE="yes" epatch
}

src_compile() {
	COMPILER=$(tc-getCC)

	echo
	echo "Compiler:	${COMPILER}"
	echo "CFLAGS:		${CFLAGS}"
	echo "LDFLAGS:	${LDFLAGS}"
	echo

	${COMPILER} ${CFLAGS} ${LDFLAGS} \
		netcat.c atomicio.c socks.c \
		-l bsd -l resolv \
		-o nc || die "build failed!"
}

src_install() {
	dobin nc

	doman nc.1
}
