EAPI="3"

inherit eutils

# omgwtf
RESTRICT="test"

DESCRIPTION="Evented IO for V8 Javascript"
HOMEPAGE="http://nodejs.org/"
SRC_URI="http://nodejs.org/dist/v${PV}/node-v${PV}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="x86 amd64"
IUSE=""

DEPEND=">=dev-lang/v8-2.5.9.6-r1
	dev-libs/openssl
	=dev-lang/python-2*"
RDEPEND="${DEPEND}"

S=${WORKDIR}/node-v${PV}

src_prepare() {
	cd ${S}
	for x in $(grep -r "/usr/bin/env python" * | cut -f1 -d":" ); do
		einfo "Tweaking $x for python2..."
		sed -e "s:/usr/bin/env python:/usr/bin/env python2:g" -i $x || die
	done
	sed -e "s/python/python2/g" -i Makefile || die
}

src_configure() {
	# this is a waf confuserator
	./configure --shared-v8 --prefix=/usr || die
}

src_compile() {
	emake || die
}

src_install() {
	emake DESTDIR="${D}" install || die
}

src_test() {
	emake test || die
}
