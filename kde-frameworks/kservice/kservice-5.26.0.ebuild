# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6

inherit kde5 eutils

DESCRIPTION="Advanced plugin and service introspection"
LICENSE="LGPL-2 LGPL-2.1+"
KEYWORDS="amd64 ~arm x86"
IUSE="+man"

RDEPEND="
	$(add_frameworks_dep kconfig)
	$(add_frameworks_dep kcoreaddons)
	$(add_frameworks_dep kcrash)
	$(add_frameworks_dep kdbusaddons)
	$(add_frameworks_dep ki18n)
	$(add_qt_dep qtdbus)
	$(add_qt_dep qtxml)
"
DEPEND="${RDEPEND}
	sys-devel/bison
	sys-devel/flex
	man? ( $(add_frameworks_dep kdoctools) )
	test? ( $(add_qt_dep qtconcurrent) )
"

# requires running kde environment
RESTRICT+=" test"

#patch file to fix problems with flex-2.6.2 version

PATCHES=( "${FILESDIR}/${PN}-5.26.0-lex.patch" )

src_prepare() {
	if declare -p PATCHES | grep -q "^declare -a "; then
		#if the user is using flex prior to version flex-2.6.3, apply patch
		if [ "$(flex --version | sed s'/flex //' | sed s'/\.//'g)" -lt "263" ]
		then
			[[ -n ${PATCHES[@]} ]] && eapply "${PATCHES[@]}"
		fi
	else
		#same thing as above - except for a patches variable that isn't a list
		if [ "$(flex --version | sed s'/flex //' | sed s'/\.//'g)" -lt "263" ]
		then
			[[ -n ${PATCHES} ]] && eapply ${PATCHES}
		fi
	fi
	eapply_user
}

src_configure() {
	local mycmakeargs=(
		$(cmake-utils_use_find_package man KF5DocTools)
	)

	kde5_src_configure
}
