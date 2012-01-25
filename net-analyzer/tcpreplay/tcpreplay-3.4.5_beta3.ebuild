# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-analyzer/tcpreplay/tcpreplay-3.4.5_beta3.ebuild,v 1.1 2012/01/22 17:53:01 jer Exp $

EAPI=4

MY_P="${P/_/}"
DESCRIPTION="replay saved tcpdump or snoop files at arbitrary speeds"
HOMEPAGE="http://tcpreplay.synfin.net/"
SRC_URI="http://synfin.net/${MY_P}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~sparc ~x86"
IUSE="debug pcapnav +tcpdump"

DEPEND="
	>=sys-devel/autogen-5.9.8
	dev-libs/libdnet
	>=net-libs/libpcap-0.9
	tcpdump? ( net-analyzer/tcpdump )
	pcapnav? ( net-libs/libpcapnav )"

RDEPEND="${DEPEND}"

S="${WORKDIR}/${MY_P}"

src_prepare() {
	echo "We don't use bundled libopts" > libopts/options.h
	./autogen.sh
}

src_configure() {
	# By default it uses static linking. Avoid that, bug 252940
	econf \
		--enable-shared \
		--enable-dynamic-link \
		--disable-local-libopts \
		$(use_with tcpdump tcpdump /usr/sbin/tcpdump) \
		$(use_with pcapnav pcapnav-config /usr/bin/pcapnav-config) \
		$(use_enable debug)
}

src_test() {
	if [[ ! ${EUID} -eq 0 ]]; then
		ewarn "Some tests were disabled due to FEATURES=userpriv"
		ewarn "To run all tests issue the following command as root:"
		ewarn " # make -C ${S}/test"
		make -C test tcpprep || die "self test failed - see ${S}/test/test.log"
	else
		make test || {
			ewarn "Note, that some tests require eth0 iface to be UP." ;
			die "self test failed - see ${S}/test/test.log" ; }
	fi
}

src_install() {
	make DESTDIR="${D}" install || die
	dodoc README docs/{CHANGELOG,CREDIT,HACKING,TODO} || die
}