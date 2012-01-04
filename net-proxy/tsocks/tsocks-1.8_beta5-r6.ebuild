
EAPI="2"

inherit multilib eutils autotools toolchain-funcs

DESCRIPTION="Transparent SOCKS v4 proxying library"
HOMEPAGE="http://tsocks.sourceforge.net/"
SRC_URI="mirror://sourceforge/tsocks/${PN}-${PV/_}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~*"
IUSE="tordns"

S="${WORKDIR}/${P%%_*}"

src_prepare() {
	epatch "${FILESDIR}/gentoo-r3.patch"
	epatch "${FILESDIR}/bsd.patch"
	epatch "${FILESDIR}/poll.patch"
	use tordns && epatch "${FILESDIR}/tordns1-r2.patch"
	eautoreconf
}

src_configure() {
	tc-export CC

	# NOTE: the docs say to install it into /lib. If you put it into
	# /usr/lib and add it to /etc/ld.so.preload on many systems /usr isn't
	# mounted in time :-( (Ben Lutgens) <lamer@gentoo.org>
	econf \
		--with-conf=/etc/socks/tsocks.conf \
		--libdir=/$(get_libdir) || die "configure failed"
}

src_compile() {
	# Fix QA notice lack of SONAME
	emake DYNLIB_FLAGS=-Wl,--soname,libtsocks.so.${PV/_beta*} || die "emake failed"
}

src_install() {
	emake DESTDIR="${D}" install || die "make install failed"
	newbin validateconf tsocks-validateconf
	newbin saveme tsocks-saveme
	dobin inspectsocks
	insinto /etc/socks
	doins tsocks.conf.*.example
	dodoc FAQ
	use tordns && dodoc README*
}

pkg_postinst() {
	einfo "Make sure you create /etc/socks/tsocks.conf from one of the examples in that directory"
	einfo "The following executables have been renamed:"
	einfo "    /usr/bin/saveme renamed to tsocks-saveme"
	einfo "    /usr/bin/validateconf renamed to tsocks-validateconf"
}
