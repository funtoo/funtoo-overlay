# Distributed under the terms of the GNU General Public License v2

EAPI=5-progress

RESTRICT="test"
PYTHON_MULTIPLE_ABIS="1"
PYTHON_RESTRICTED_ABIS="3.* *-jython *-pypy-*"
inherit python pax-utils

DESCRIPTION="Evented IO for V8 Javascript"
HOMEPAGE="http://nodejs.org/"
SRC_URI="http://nodejs.org/dist/v${PV}/node-v${PV}.tar.gz"

LICENSE="Apache-1.1 Apache-2.0 BSD BSD-2 MIT"
SLOT="0"
KEYWORDS="~*"
IUSE="v8 +npm"

RDEPEND="dev-libs/openssl
		v8? ( >=dev-lang/v8-3.18.5.1 )"
DEPEND="${RDEPEND}
	$(python_abi_depend virtual/python-json)"

S=${WORKDIR}/node-v${PV}

src_prepare() {
	# fix compilation on Darwin
	# http://code.google.com/p/gyp/issues/detail?id=260
	sed -i -e "/append('-arch/d" tools/gyp/pylib/gyp/xcode_emulation.py || die

	# make sure we use python2.* while using gyp
	sed -i -e  "s/python/python2/" deps/npm/node_modules/node-gyp/gyp/gyp || die

	# less verbose install output (stating the same as portage, basically)
	sed -i -e "/print/d" tools/install.py || die
	sed -i -e "s~/usr/local~/usr~" tools/install.py || die
}

src_configure() {
	local myconf=""
	! use npm && myconf+="--without-npm "
	use v8 && myconf+="--shared-v8 --shared-v8-libpath=${EPREFIX}/usr/lib --shared-v8-includes=${EPREFIX}/usr/include"

	./configure --prefix="${EPREFIX}"/usr --shared-openssl --shared-zlib ${myconf} || die
	sed -i -e "s~/usr/local~/usr~g" out/Makefile || die
	sed -i -e "s~/usr/local~/usr~g" Makefile || die
}

src_compile() {
	emake out/Makefile
	# emake -C out mksnapshot
	# pax-mark m out/Release/mksnapshot
	emake || die
}

src_install() {
	./tools/install.py install "${ED}"

	use npm && dohtml -r "${ED}"/usr/lib/node_modules/npm/html/*

	rm -rf "${ED}"/usr/lib/node_modules/npm/doc "${ED}"/usr/lib/node_modules/npm/html
	rm -rf "${ED}"/usr/lib/dtrace

	pax-mark -m "${ED}"/usr/bin/node
}

src_test() {
	./tools/test.py --mode=release simple message || die
}

pkg_postinst() {
	if ! use v8 ; then
		elog "${PN} has been compiled against internal v8"
		elog "to use system v8 you will need to emerge a"
		elog "version >=dev-lag/v8-3.18"
	fi
}
