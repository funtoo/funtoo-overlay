# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-apps/portage/portage-2.2_rc98.ebuild,v 1.1 2010/10/18 11:54:33 zmedico Exp $

# Require EAPI 2 since we now require at least python-2.6 (for python 3
# syntax support) which also requires EAPI 2.
EAPI=2
inherit eutils multilib python

DESCRIPTION="Portage is the package management and distribution system for Gentoo"
HOMEPAGE="http://www.gentoo.org/proj/en/portage/index.xml"
LICENSE="GPL-2"
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~m68k ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~sparc-fbsd ~x86 ~x86-fbsd"
PROVIDE="virtual/portage"
SLOT="0"
IUSE="build doc epydoc experimental +ipc linguas_pl python3 selinux"
GITHUB_REPO="portage-funtoo"
GITHUB_USER="funtoo"

if use experimental ; then
	GITHUB_TAG="funtoo-path"
else
	GITHUB_TAG="funtoo-${PVR}"
fi

python_dep="python3? ( =dev-lang/python-3* )
	!python3? (
		build? ( || ( dev-lang/python:2.8 dev-lang/python:2.7 dev-lang/python:2.6 ) )
		!build? ( || ( dev-lang/python:2.8 dev-lang/python:2.7 dev-lang/python:2.6 >=dev-lang/python-3 ) )
	)"

# The pysqlite blocker is for bug #282760.
DEPEND="${python_dep}
	!build? ( >=sys-apps/sed-4.0.5 )
	doc? ( app-text/xmlto ~app-text/docbook-xml-dtd-4.4 )
	epydoc? ( >=dev-python/epydoc-2.0 !<=dev-python/pysqlite-2.4.1 )"
# Require sandbox-2.2 for bug #288863.
RDEPEND="${python_dep}
	!build? ( >=sys-apps/sed-4.0.5
		>=app-shells/bash-3.2_p17
		>=app-admin/eselect-1.2 )
	elibc_FreeBSD? ( sys-freebsd/freebsd-bin )
	elibc_glibc? ( >=sys-apps/sandbox-2.2 )
	elibc_uclibc? ( >=sys-apps/sandbox-2.2 )
	>=app-misc/pax-utils-0.1.17
	selinux? ( sys-libs/libselinux )
	!<app-shells/bash-3.2_p17
	>=net-misc/wget-1.12-r3"
PDEPEND="
	!build? (
		>=net-misc/rsync-2.6.4
		userland_GNU? ( >=sys-apps/coreutils-6.4 )
	)"
# coreutils-6.4 rdep is for date format in emerge-webrsync #164532
# rsync-2.6.4 rdep is for the --filter option #167668

SRC_ARCHIVES="http://dev.gentoo.org/~zmedico/portage/archives"

prefix_src_archives() {
	local x y
	for x in ${@}; do
		for y in ${SRC_ARCHIVES}; do
			echo ${y}/${x}
		done
	done
}

PV_PL="2.1.2"
PATCHVER_PL=""
SRC_URI="https://www.github.com/${GITHUB_USER}/${GITHUB_REPO}/tarball/${GITHUB_TAG} -> portage-${GITHUB_TAG}.tar.gz"
SRC_URI="$SRC_URI linguas_pl? ( mirror://gentoo/${PN}-man-pl-${PV_PL}.tar.bz2 )"

S_PL="${WORKDIR}"/${PN}-${PV_PL}

compatible_python_is_selected() {
	[[ $(/usr/bin/python -c 'import sys ; sys.stdout.write(sys.hexversion >= 0x2060000 and "good" or "bad")') = good ]]
}

pkg_setup() {
	if ! use python3 && ! compatible_python_is_selected ; then
		ewarn "Attempting to select a compatible default python interpreter"
		local x success=0
		for x in /usr/bin/python2.* ; do
			x=${x#/usr/bin/python2.}
			if [[ $x -ge 6 ]] 2>/dev/null ; then
				eselect python set python2.$x
				if compatible_python_is_selected ; then
					elog "Default python interpreter is now set to python-2.$x"
					success=1
					break
				fi
			fi
		done
		if [ $success != 1 ] ; then
			eerror "Unable to select a compatible default python interpreter!"
			die "This version of portage requires at least python-2.6 to be selected as the default python interpreter (see \`eselect python --help\`)."
		fi
	fi

	if use python3; then
		python_set_active_version 3
	fi
}

src_unpack() {
	unpack ${A}
	mv "${WORKDIR}/${GITHUB_USER}-${PN}-funtoo"-??????? "${S}" || die
}

src_prepare() {
	cd ${S}
	if [ -n "${PATCHVER}" ] ; then
		if [[ -L $S/bin/ebuild-helpers/portageq ]] ; then
			rm "$S/bin/ebuild-helpers/portageq" \
				|| die "failed to remove portageq helper symlink"
		fi
		epatch "${WORKDIR}/${PN}-${PATCHVER}.patch"
	fi
	einfo "Setting portage.VERSION to ${PVR} ..."
	sed -e "s/^VERSION=.*/VERSION=\"${PVR}\"/" -i pym/portage/__init__.py || \
		die "Failed to patch portage.VERSION"
	sed -e "1s/VERSION/${PVR}/" -i doc/fragment/version || \
		die "Failed to patch VERSION in doc/fragment/version"
	sed -e "1s/VERSION/${PVR}/" -i man/* || \
		die "Failed to patch VERSION in man page headers"

	if ! use ipc ; then
		einfo "Disabling ipc..."
		sed -e "s:_enable_ipc_daemon = True:_enable_ipc_daemon = False:" \
			-i pym/_emerge/AbstractEbuildProcess.py || \
			die "failed to patch AbstractEbuildProcess.py"
	fi

	if use python3; then
		einfo "Converting shebangs for python3..."
		python_convert_shebangs -r 3 .
	fi
}

src_compile() {
	if use doc; then
		cd "${S}"/doc
		touch fragment/date
		make xhtml xhtml-nochunks || die "failed to make docs"
	fi

	if use epydoc; then
		einfo "Generating api docs"
		mkdir "${WORKDIR}"/api
		local my_modules epydoc_opts=""
		my_modules="$(find "${S}/pym" -name "*.py" \
			| sed -e 's:/__init__.py$::' -e 's:\.py$::' -e "s:^${S}/pym/::" \
			 -e 's:/:.:g' | sort)" || die "error listing modules"
		# workaround for bug 282760
		> "$S/pym/pysqlite2.py"
		PYTHONPATH=${S}/pym:${PYTHONPATH:+:}${PYTHONPATH} \
			epydoc -o "${WORKDIR}"/api \
			-qqqqq --no-frames --show-imports $epydoc_opts \
			--name "${PN}" --url "${HOMEPAGE}" \
			${my_modules} || die "epydoc failed"
		rm "$S/pym/pysqlite2.py"
	fi
}

src_test() {
	# make files executable, in case they were created by patch
	find bin -type f | xargs chmod +x
	PYTHONPATH=${S}/pym:${PYTHONPATH:+:}${PYTHONPATH} \
		./pym/portage/tests/runTests || die "test(s) failed"
}

src_install() {
	local libdir=$(get_libdir)
	local portage_base="/usr/${libdir}/portage"
	local portage_share_config=/usr/share/portage/config

	cd "${S}"/cnf
	insinto /etc
	doins etc-update.conf dispatch-conf.conf || die

	insinto "$portage_share_config/sets"
	doins "$S"/cnf/sets/*.conf || die
	insinto "$portage_share_config"
	doins "$S/cnf/make.globals" || die
	if [ -f "make.conf.${ARCH}".diff ]; then
		patch make.conf "make.conf.${ARCH}".diff || \
			die "Failed to patch make.conf.example"
		newins make.conf make.conf.example || die
	else
		eerror ""
		eerror "Portage does not have an arch-specific configuration for this arch."
		eerror "Please notify the arch maintainer about this issue. Using generic."
		eerror ""
		newins make.conf make.conf.example || die
	fi

	dosym ..${portage_share_config}/make.globals /etc/make.globals

	insinto /etc/logrotate.d
	doins "${S}"/cnf/logrotate.d/elog-save-summary || die

	# Funtoo has removed the sed wrapper from the upstream sources...

	local x symlinks

	cd "$S" || die "cd failed"
	for x in $(find bin -type d) ; do
		exeinto $portage_base/$x || die "exeinto failed"
		cd "$S"/$x || die "cd failed"
		doexe $(find . -mindepth 1 -maxdepth 1 -type f ! -type l) || \
			die "doexe failed"
		symlinks=$(find . -mindepth 1 -maxdepth 1 -type l)
		if [ -n "$symlinks" ] ; then
			cp -P $symlinks "$D$portage_base/$x" || die "cp failed"
		fi
	done

	# create this manually until it's in a release tarball
	dosym ../../banned-helper $portage_base/bin/ebuild-helpers/4/prepalldocs

	cd "$S" || die "cd failed"
	for x in $(find pym/* -type d) ; do
		insinto $portage_base/$x || die "insinto failed"
		cd "$S"/$x || die "cd failed"
		# __pycache__ directories contain no py files
		[[ "*.py" != $(echo *.py) ]] || continue
		doins *.py || die "doins failed"
		symlinks=$(find . -mindepth 1 -maxdepth 1 -type l)
		if [ -n "$symlinks" ] ; then
			cp -P $symlinks "$D$portage_base/$x" || die "cp failed"
		fi
	done

	# Symlinks to directories cause up/downgrade issues and the use of these
	# modules outside of portage is probably negligible.
	for x in "${D}${portage_base}/pym/"{cache,elog_modules} ; do
		[ ! -L "${x}" ] && continue
		die "symlink to directory will cause upgrade/downgrade issues: '${x}'"
	done

	exeinto ${portage_base}/pym/portage/tests
	doexe  "${S}"/pym/portage/tests/runTests

	doman "${S}"/man/*.[0-9]
	if use linguas_pl; then
		doman -i18n=pl "${S_PL}"/man/pl/*.[0-9]
		doman -i18n=pl_PL.UTF-8 "${S_PL}"/man/pl_PL.UTF-8/*.[0-9]
	fi

	dodoc "${S}"/{NEWS,RELEASE-NOTES}
	use doc && dohtml -r "${S}"/doc/*
	use epydoc && dohtml -r "${WORKDIR}"/api

	dodir /usr/bin
	for x in ebuild egencache emerge portageq quickpkg repoman ; do
		dosym ../${libdir}/portage/bin/${x} /usr/bin/${x}
	done

	dodir /usr/sbin
	local my_syms="archive-conf
		dispatch-conf
		emaint
		env-update
		etc-update
		fixpackages
		regenworld"
	local x
	for x in ${my_syms}; do
		dosym ../${libdir}/portage/bin/${x} /usr/sbin/${x}
	done
	dosym env-update /usr/sbin/update-env
	dosym etc-update /usr/sbin/update-etc

	dodir /etc/portage
	keepdir /etc/portage
}

pkg_preinst() {
	if ! use build && ! has_version dev-python/pycrypto && \
		! has_version '>=dev-lang/python-2.6[ssl]' ; then
		ewarn "If you are an ebuild developer and you plan to commit ebuilds"
		ewarn "with this system then please install dev-python/pycrypto or"
		ewarn "enable the ssl USE flag for >=dev-lang/python-2.6 in order"
		ewarn "to enable RMD160 hash support."
		ewarn "See bug #198398 for more information."
	fi
	if [ -f "${ROOT}/etc/make.globals" ]; then
		rm "${ROOT}/etc/make.globals"
	fi

	has_version "<${CATEGORY}/${PN}-2.2_alpha"
	MINOR_UPGRADE=$?

	has_version "<=${CATEGORY}/${PN}-2.2_pre5"
	WORLD_MIGRATION_UPGRADE=$?

	# If portage-2.1.6 is installed and the preserved_libs_registry exists,
	# assume that the NEEDED.ELF.2 files have already been generated.
	has_version "<=${CATEGORY}/${PN}-2.2_pre7" && \
		! ( [ -e "$ROOT"var/lib/portage/preserved_libs_registry ] && \
		has_version ">=${CATEGORY}/${PN}-2.1.6_rc" )
	NEEDED_REBUILD_UPGRADE=$?

	[[ -n $PORTDIR_OVERLAY ]] && has_version "<${CATEGORY}/${PN}-2.1.6.12"
	REPO_LAYOUT_CONF_WARN=$?
}

pkg_postinst() {
	# Compile all source files recursively. Any orphans
	# will be identified and removed in postrm.
	python_mod_optimize /usr/$(get_libdir)/portage/pym

	if [ $WORLD_MIGRATION_UPGRADE = 0 ] ; then
		einfo "moving set references from the worldfile into world_sets"
		cd "${ROOT}/var/lib/portage/"
		grep "^@" world >> world_sets
		sed -i -e '/^@/d' world
	fi

	if [ $NEEDED_REBUILD_UPGRADE = 0 ] ; then
		einfo "rebuilding NEEDED.ELF.2 files"
		for cpv in "${ROOT}/var/db/pkg"/*/*; do
			if [ -f "${cpv}/NEEDED" ]; then
				rm -f "${cpv}/NEEDED.ELF.2"
				while read line; do
					filename=${line% *}
					needed=${line#* }
					needed=${needed//+/++}
					needed=${needed//#/##}
					needed=${needed//%/%%}
					newline=$(scanelf -BF "%a;%F;%S;%r;${needed}" $filename)
					newline=${newline//  -  }
					echo "${newline:3}" >> "${cpv}/NEEDED.ELF.2"
				done < "${cpv}/NEEDED"
			fi
		done
	fi

	if [ $REPO_LAYOUT_CONF_WARN = 0 ] ; then
		ewarn
		echo "If you want overlay eclasses to override eclasses from" \
			"other repos then see the portage(5) man page" \
			"for information about the new layout.conf and repos.conf" \
			"configuration files." \
			| fmt -w 75 | while read -r ; do ewarn "$REPLY" ; done
		ewarn
	fi

	einfo
	einfo "For help with using portage please consult the Gentoo Handbook"
	einfo "at http://www.gentoo.org/doc/en/handbook/handbook-x86.xml?part=3"
	einfo

	if [ $MINOR_UPGRADE = 0 ] ; then
		elog "If you're upgrading from a pre-2.2 version of portage you might"
		elog "want to remerge world (emerge -e world) to take full advantage"
		elog "of some of the new features in 2.2."
		elog "This is not required however for portage to function properly."
		elog
	fi

	if [ -z "${PV/*_rc*}" ]; then
		elog "If you always want to use the latest development version of portage"
		elog "please read http://www.gentoo.org/proj/en/portage/doc/testing.xml"
		elog
	fi
}

pkg_postrm() {
	python_mod_cleanup /usr/$(get_libdir)/portage/pym
}
