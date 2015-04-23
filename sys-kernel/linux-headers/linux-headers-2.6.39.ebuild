# Distributed under the terms of the GNU General Public License v2

EAPI="3"

ETYPE="headers"
H_SUPPORTEDARCH="alpha amd64 arm bfin cris hppa m68k mips ia64 ppc ppc64 s390 sh sparc x86"
inherit kernel-2
detect_version

PATCH_VER="1"
SRC_URI="mirror://funtoo/distfiles/gentoo-headers-base-${PV}.tar.xz"
[[ -n ${PATCH_VER} ]] && SRC_URI="${SRC_URI} mirror://funtoo/distfiles/gentoo-headers-${PV}-${PATCH_VER}.tar.xz"

KEYWORDS="*"
RESTRICT="mirror"
DEPEND="app-arch/xz-utils"
RDEPEND=""

S=${WORKDIR}/gentoo-headers-base-${PV}

src_unpack() {
	unpack ${A}
}

src_prepare() {
	[[ -n ${PATCH_VER} ]] && EPATCH_SUFFIX="patch" epatch "${WORKDIR}"/${PV}
}

src_install() {
	kernel-2_src_install
	cd "${D}"
	egrep -r \
		-e '(^|[[:space:](])(asm|volatile|inline)[[:space:](]' \
		-e '\<([us](8|16|32|64))\>' \
		.
	headers___fix $(find -type f)

	egrep -l -r -e '__[us](8|16|32|64)' "${D}" | xargs grep -L linux/types.h

	# hrm, build system sucks
	find "${D}" '(' -name '.install' -o -name '*.cmd' ')' -print0 | xargs -0 rm -f

	# provided by libdrm (for now?)
	rm -rf "${D}"/$(kernel_header_destdir)/drm
}

src_test() {
	emake ARCH=$(tc-arch-kernel) headers_check || die
}
