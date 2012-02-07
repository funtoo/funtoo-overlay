# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/dev-lang/perl/perl-5.14.2.ebuild,v 1.3 2012/01/02 22:52:21 zmedico Exp $

EAPI=4

inherit eutils alternatives flag-o-matic toolchain-funcs multilib

PATCH_VER=1

PERL_OLDVERSEN="5.14.0 5.14.1"
MODULE_AUTHOR=FLORA

SHORT_PV="${PV%.*}"
MY_P="perl-${PV/_rc/-RC}"
MY_PV="${PV%_rc*}"

DESCRIPTION="Larry Wall's Practical Extraction and Report Language"

SRC_URI="
	mirror://cpan/src/${MY_P}.tar.bz2
	mirror://cpan/authors/id/${MODULE_AUTHOR:0:1}/${MODULE_AUTHOR:0:2}/${MODULE_AUTHOR}/${MY_P}.tar.bz2
	mirror://gentoo/${MY_P}-${PATCH_VER}.tar.bz2
	http://dev.gentoo.org/~tove/distfiles/${CATEGORY}/${PN}/${MY_P}-${PATCH_VER}.tar.bz2"
#	mirror://cpan/src/${MY_P}.tar.bz2
#	mirror://gentoo/${MY_P}-${PATCH_VER}.tar.bz2
HOMEPAGE="http://www.perl.org/"

LICENSE="|| ( Artistic GPL-1 GPL-2 GPL-3 )"
SLOT="0"
KEYWORDS="~*"
IUSE="berkdb build debug doc gdbm ithreads"

COMMON_DEPEND="berkdb? ( sys-libs/db )
	gdbm? ( >=sys-libs/gdbm-1.8.3 )
	app-arch/bzip2
	sys-libs/zlib"
DEPEND="${COMMON_DEPEND}
	elibc_FreeBSD? ( sys-freebsd/freebsd-mk-defs )"
RDEPEND="${COMMON_DEPEND}"
PDEPEND=">=app-admin/perl-cleaner-2.5"
PROVIDE="sys-devel/libperl"

S="${WORKDIR}/${MY_P}"

dual_scripts() {
	src_remove_dual      perl-core/Archive-Tar        1.760.0      ptar ptardiff ptargrep
	src_remove_dual      perl-core/Digest-SHA         5.610.0      shasum
	src_remove_dual      perl-core/CPAN               1.960.1_rc   cpan
	src_remove_dual      perl-core/CPANPLUS           0.910.300    cpanp cpan2dist
	src_remove_dual_file perl-core/CPANPLUS           0.910.300    /usr/bin/cpanp-run-perl
	src_remove_dual      perl-core/Encode             2.420.100_rc enc2xs piconv
	src_remove_dual      perl-core/ExtUtils-MakeMaker 6.570.500_rc instmodsh
	src_remove_dual      perl-core/ExtUtils-ParseXS   2.221.0      xsubpp
	src_remove_dual      perl-core/JSON-PP            2.271.50     json_pp
	src_remove_dual      perl-core/Module-Build       0.380.0      config_data
	src_remove_dual      perl-core/Module-CoreList    2.490.200_rc corelist
	src_remove_dual      perl-core/PodParser          1.370.0      pod2usage podchecker podselect
	src_remove_dual      perl-core/Test-Harness       3.230.0      prove
	src_remove_dual      perl-core/podlators          2.4.0        pod2man pod2text
	src_remove_dual_man  perl-core/podlators          2.4.0        /usr/share/man/man1/perlpodstyle.1
}

pkg_pretend() {
	check_rebuild
}

pkg_setup() {
	case ${CHOST} in
		*-freebsd*)   osname="freebsd" ;;
		*-dragonfly*) osname="dragonfly" ;;
		*-netbsd*)    osname="netbsd" ;;
		*-openbsd*)   osname="openbsd" ;;
		*-darwin*)    osname="darwin" ;;
		*)            osname="linux" ;;
	esac

	if use ithreads ; then
		mythreading="-multi"
		myarch="${CHOST%%-*}-${osname}-thread"
	else
		myarch="${CHOST%%-*}-${osname}"
	fi
	if use debug ; then
		myarch="${myarch}-debug"
	fi

	LIBPERL="libperl$(get_libname ${MY_PV} )"
	PRIV_LIB="/usr/$(get_libdir)/perl5/${MY_PV}"
	ARCH_LIB="/usr/$(get_libdir)/perl5/${MY_PV}/${myarch}${mythreading}"
	SITE_LIB="/usr/$(get_libdir)/perl5/site_perl/${MY_PV}"
	SITE_ARCH="/usr/$(get_libdir)/perl5/site_perl/${MY_PV}/${myarch}${mythreading}"
	VENDOR_LIB="/usr/$(get_libdir)/perl5/vendor_perl/${MY_PV}"
	VENDOR_ARCH="/usr/$(get_libdir)/perl5/vendor_perl/${MY_PV}/${myarch}${mythreading}"

	if use ithreads ; then
		echo ""
		ewarn "THREADS WARNING:"
		ewarn "PLEASE NOTE: You are compiling ${MY_P} with"
		ewarn "interpreter-level threading enabled."
		ewarn "Threading is not supported by all applications "
		ewarn "that compile against perl. You use threading at "
		ewarn "your own discretion. "
	fi
	check_rebuild
	dual_scripts
}

check_rebuild() {
	if has_version "<dev-lang/perl-${SHORT_PV}" ; then
		echo ""
		ewarn "UPDATE THE PERL MODULES:"
		ewarn "After updating dev-lang/perl you must reinstall"
		ewarn "the installed perl modules."
		ewarn "Use: perl-cleaner --all"
	elif has_version dev-lang/perl ; then
		# doesnot work
		#if ! has_version dev-lang/perl[ithreads=,debug=] ; then
		#if ! has_version dev-lang/perl[ithreads=] || ! has_version dev-lang/perl[debug=] ; then
		if (   use ithreads && ! has_version dev-lang/perl[ithreads] ) || \
		   ( ! use ithreads &&   has_version dev-lang/perl[ithreads] ) || \
		   (   use debug    && ! has_version dev-lang/perl[debug]    ) || \
		   ( ! use debug    &&   has_version dev-lang/perl[debug]    ) ; then
			echo ""
			ewarn "TOGGLED USE-FLAGS WARNING:"
			ewarn "You changed one of the use-flags ithreads or debug."
			ewarn "You must rebuild all perl-modules installed."
			ewarn "Use: perl-cleaner --modules ; perl-cleaner --force --libperl"
		fi
	fi
	dual_scripts
}

src_prepare_update_patchlevel_h() {
	[[ -f ${WORKDIR}/perl-patch/series ]] || return 0

	while read patch level ; do
		sed -i -e "s/^\t,NULL$/	,\"${patch//__/_}\"\n&/" "${S}"/patchlevel.h || die
	done < "${WORKDIR}"/perl-patch/series
}

src_prepare() {
	EPATCH_SOURCE="${WORKDIR}/perl-patch" \
	EPATCH_SUFFIX="diff" \
	EPATCH_FORCE="yes" \
	EPATCH_OPTS="-p1" \
	epatch

	src_prepare_update_patchlevel_h

	# pod/perltoc.pod fails
	# lib/ExtUtils/t/Embed.t fails
	ln -s ${LIBPERL} libperl$(get_libname ${SHORT_PV})
	ln -s ${LIBPERL} libperl$(get_libname )
}

myconf() {
	# the myconf array is declared in src_configure
	myconf=( "${myconf[@]}" "$@" )
}

src_configure() {
	declare -a myconf

	export LC_ALL="C"
	[[ ${COLUMNS:-1} -ge 1 ]] || unset COLUMNS # bug #394091

	# some arches and -O do not mix :)
	use ppc && replace-flags -O? -O1
	# Perl has problems compiling with -Os in your flags with glibc
	use elibc_uclibc || replace-flags "-Os" "-O2"
	# This flag makes compiling crash in interesting ways
	filter-flags "-malign-double"
	# Fixes bug #97645
	use ppc && filter-flags "-mpowerpc-gpopt"
	# Fixes bug #143895 on gcc-4.1.1
	filter-flags "-fsched2-use-superblocks"

	use sparc && myconf -Ud_longdbl

	# 266337
	export BUILD_BZIP2=0
	export BZIP2_INCLUDE=/usr/include
	export BZIP2_LIB=/usr/$(get_libdir)
	cat <<-EOF > "${S}/cpan/Compress-Raw-Zlib/config.in"
		BUILD_ZLIB = False
		INCLUDE = /usr/include
		LIB = /usr/$(get_libdir)

		OLD_ZLIB = False
		GZIP_OS_CODE = AUTO_DETECT
	EOF

	# allow either gdbm to provide ndbm (in <gdbm/ndbm.h>) or db1

	myndbm='U'
	mygdbm='U'
	mydb='U'

	if use gdbm ; then
		mygdbm='D'
		myndbm='D'
	fi
	if use berkdb ; then
		mydb='D'
		has_version '=sys-libs/db-1*' && myndbm='D'
	fi

	myconf "-${myndbm}i_ndbm" "-${mygdbm}i_gdbm" "-${mydb}i_db"

	if use alpha && [[ "$(tc-getCC)" = "ccc" ]] ; then
		ewarn "Perl will not be built with berkdb support, use gcc if you needed it..."
		myconf -Ui_db -Ui_ndbm
	fi

	use ithreads && myconf -Dusethreads

	if use debug ; then
		append-cflags "-g"
		myconf -DDEBUGGING
	elif [[ ${CFLAGS} == *-g* ]] ; then
		myconf -DDEBUGGING=-g
	else
		myconf -DDEBUGGING=none
	fi

	if [[ -n ${PERL_OLDVERSEN} ]] ; then
		local inclist=$(for v in ${PERL_OLDVERSEN}; do echo -n "${v}/${myarch}${mythreading} ${v} "; done )
		myconf -Dinc_version_list="${inclist}"
	fi

	[[ ${ELIBC} == "FreeBSD" ]] && myconf "-Dlibc=/usr/$(get_libdir)/libc.a"

	if [[ $(get_libdir) != "lib" ]] ; then
		# We need to use " and not ', as the written config.sh use ' ...
		myconf "-Dlibpth=/usr/local/$(get_libdir) /$(get_libdir) /usr/$(get_libdir)"
	fi

	sh Configure \
		-des \
		-Duseshrplib \
		-Darchname="${myarch}" \
		-Dcc="$(tc-getCC)" \
		-Doptimize="${CFLAGS}" \
		-Dldflags="${LDFLAGS}" \
		-Dprefix='/usr' \
		-Dsiteprefix='/usr' \
		-Dvendorprefix='/usr' \
		-Dscriptdir='/usr/bin' \
		-Dprivlib="${PRIV_LIB}" \
		-Darchlib="${ARCH_LIB}" \
		-Dsitelib="${SITE_LIB}" \
		-Dsitearch="${SITE_ARCH}" \
		-Dvendorlib="${VENDOR_LIB}" \
		-Dvendorarch="${VENDOR_ARCH}" \
		-Dman1dir=/usr/share/man/man1 \
		-Dman3dir=/usr/share/man/man3 \
		-Dsiteman1dir=/usr/share/man/man1 \
		-Dsiteman3dir=/usr/share/man/man3 \
		-Dvendorman1dir=/usr/share/man/man1 \
		-Dvendorman3dir=/usr/share/man/man3 \
		-Dman1ext='1' \
		-Dman3ext='3pm' \
		-Dlibperl="${LIBPERL}" \
		-Dlocincpth=' ' \
		-Duselargefiles \
		-Dd_semctl_semun \
		-Dcf_by='Gentoo' \
		-Dmyhostname='localhost' \
		-Dperladmin='root@localhost' \
		-Dinstallusrbinperl='n' \
		-Ud_csh \
		-Uusenm \
		"${myconf[@]}" || die "Unable to configure"
}

src_compile() {
	# bug 331113
	emake -j1 || die "emake failed"
}

src_test() {
	if [[ ${EUID} == 0 ]] ; then
		ewarn "Test fails with a sandbox error (#328793) if run as root. Skipping tests..."
		return 0
	fi
	use elibc_uclibc && export MAKEOPTS+=" -j1"
	TEST_JOBS=$(echo -j1 ${MAKEOPTS} | sed -r 's/.*(-j[[:space:]]*|--jobs=)([[:digit:]]+).*/\2/' ) \
		make test_harness || die "test failed"
}

src_install() {
	local i
	local coredir="${ARCH_LIB}/CORE"

	local installtarget=install
	if use build ; then
		installtarget=install.perl
	fi
	make DESTDIR="${D}" ${installtarget} || die "Unable to make ${installtarget}"

	rm -f "${D}"/usr/bin/perl
	ln -s perl${MY_PV} "${D}"/usr/bin/perl || die

	dolib.so "${D}"${coredir}/${LIBPERL}
	dosym ${LIBPERL} /usr/$(get_libdir)/libperl$(get_libname ${SHORT_PV}) || die
	dosym ${LIBPERL} /usr/$(get_libdir)/libperl$(get_libname) || die
	rm -f "${D}"/${coredir}/${LIBPERL}
	dosym ../../../../../$(get_libdir)/${LIBPERL} ${coredir}/${LIBPERL}
	dosym ../../../../../$(get_libdir)/${LIBPERL} ${coredir}/libperl$(get_libname ${SHORT_PV})
	dosym ../../../../../$(get_libdir)/${LIBPERL} ${coredir}/libperl$(get_libname)e

	rm -rf "${D}"/usr/share/man/man3 || die "Unable to remove module man pages"

#	# A poor fix for the miniperl issues
#	dosed 's:./miniperl:/usr/bin/perl:' /usr/$(get_libdir)/perl5/${MY_PV}/ExtUtils/xsubpp
#	fperms 0444 /usr/$(get_libdir)/perl5/${MY_PV}/ExtUtils/xsubpp
#	dosed 's:./miniperl:/usr/bin/perl:' /usr/bin/xsubpp
#	fperms 0755 /usr/bin/xsubpp

	# This removes ${D} from Config.pm
	for i in $(find "${D}" -iname "Config.pm" ) ; do
		einfo "Removing ${D} from ${i}..."
		sed -i -e "s:${D}::" "${i}" || die "Sed failed"
	done

	find "${D}" -type f -name .packlist -delete || die

	# Note: find out from psm why we would need/want this.
	# ( use berkdb && has_version '=sys-libs/db-1*' ) ||
	#	find "${D}" -name "*NDBM*" | xargs rm -f

	dodoc Changes* README AUTHORS

	if use doc ; then
		# HTML Documentation
		# We expect errors, warnings, and such with the following.

		dodir /usr/share/doc/${PF}/html
		LD_LIBRARY_PATH=. ./perl installhtml \
			--podroot='.' \
			--podpath='lib:ext:pod:vms' \
			--recurse \
			--htmldir="${D}/usr/share/doc/${PF}/html" \
			--libpods='perlfunc:perlguts:perlvar:perlrun:perlop'
	fi

	if use build ; then
		src_remove_extra_files
	fi

	dual_scripts
}

pkg_postinst() {
	dual_scripts

	if [[ "${ROOT}" = "/" ]] ; then
		local INC DIR file
		INC=$(perl -e 'for $line (@INC) { next if $line eq "."; next if $line =~ m/'${MY_PV}'|etc|local|perl$/; print "$line\n" }')
		einfo "Removing old .ph files"
		for DIR in ${INC} ; do
			if [[ -d "${DIR}" ]] ; then
				for file in $(find "${DIR}" -name "*.ph" -type f ) ; do
					rm -f "${file}"
					einfo "<< ${file}"
				done
			fi
		done
		# Silently remove the now empty dirs
		for DIR in ${INC} ; do
			if [[ -d "${DIR}" ]] ; then
				find "${DIR}" -depth -type d -print0 | xargs -0 -r rmdir &> /dev/null
			fi
		done
		if ! use build ; then
			ebegin "Generating ConfigLocal.pm (ignore any error)"
			enc2xs -C
		fi

		einfo "Converting C header files to the corresponding Perl format (ignore any error)"
		pushd /usr/include >/dev/null
			h2ph -Q -a -d ${ARCH_LIB} \
				asm/termios.h syscall.h syslimits.h syslog.h sys/ioctl.h \
				sys/socket.h sys/time.h wait.h sysexits.h
		popd >/dev/null

# This has been moved into a function because rumor has it that a future release
# of portage will allow us to check what version was just removed - which means
# we will be able to invoke this only as needed :)
		# Tried doing this via  -z, but $INC is too big...
		#if [[ "${INC}x" != "x" ]]; then
		#	cleaner_msg
		#fi
	fi
}

pkg_postrm(){
	dual_scripts

#	if [[ -e ${ARCH_LIB}/Encode/ConfigLocal.pm ]] ; then
#		ebegin "Removing ConfigLocal.pm"
#		rm "${ARCH_LIB}/Encode/ConfigLocal.pm"
#	fi
}

cleaner_msg() {
	eerror "You have had multiple versions of perl. It is recommended"
	eerror "that you run perl-cleaner now. perl-cleaner will"
	eerror "assist with this transition. This script is capable"
	eerror "of cleaning out old .ph files, rebuilding modules for "
	eerror "your new version of perl, as well as re-emerging"
	eerror "applications that compiled against your old libperl$(get_libname)"
	eerror
	eerror "PLEASE DO NOT INTERRUPT THE RUNNING OF THIS SCRIPT."
	eerror "Part of the rebuilding of applications compiled against "
	eerror "your old libperl involves temporarily unmerging"
	eerror "them - interruptions could leave you with unmerged"
	eerror "packages before they can be remerged."
	eerror ""
	eerror "If you have run perl-cleaner and a package still gives"
	eerror "you trouble, and re-emerging it fails to correct"
	eerror "the problem, please check http://bugs.gentoo.org/"
	eerror "for more information or to report a bug."
	eerror ""
}

src_remove_dual_file() {
	local i pkg ver
	pkg="$1"
	ver="$2"
	shift 2
	case "${EBUILD_PHASE:-none}" in
		postinst|postrm)
			for i in "$@" ; do
				alternatives_auto_makesym "${i}" "${i}-[0-9]*"
			done
			;;
		setup)
			for i in "$@" ; do
				if [[ -f ${ROOT}${i} && ! -h ${ROOT}${i} ]] ; then
					has_version ${pkg} && ewarn "You must reinstall ${pkg} !"
					break
				fi
			done
			;;
		install)
			for i in "$@" ; do
				if ! [[ -f "${D}"${i} ]] ; then
					use build || ewarn "${i} does not exist!"
					continue
				fi
				mv "${D}"${i}{,-${ver}-${P}} || die
			done
			;;
	esac
}

src_remove_dual_man() {
	local i pkg ver ff
	pkg="$1"
	ver="$2"
	shift 2
	case "${EBUILD_PHASE:-none}" in
		postinst|postrm)
			for i in "$@" ; do
				ff=`echo "${ROOT}${i%.[0-9]}-${ver}-${P}${i#${i%.[0-9]}}"*`
				ff=${ff##*${i#${i%.[0-9]}}}
				alternatives_auto_makesym "${i}${ff}" "${i%.[0-9]}-[0-9]*"
			done
			;;
		install)
			for i in "$@" ; do
				if ! [[ -f "${D}"${i} ]] ; then
					use build || ewarn "${i} does not exist!"
					continue
				fi
				mv "${D}"${i} "${D}"${i%.[0-9]}-${ver}-${P}${i#${i%.[0-9]}} || die
			done
			;;
	esac
}

src_remove_dual() {
	local i pkg ver
	pkg="$1"
	ver="$2"
	shift 2
	for i in "$@" ; do
		src_remove_dual_file  "${pkg}" "${ver}" "/usr/bin/${i}"
		src_remove_dual_man   "${pkg}" "${ver}" "/usr/share/man/man1/${i}.1"
	done
}

src_remove_extra_files() {
	local prefix="./usr" # ./ is important
	local bindir="${prefix}/bin"
	local libdir="${prefix}/$(get_libdir)"

	# I made this list from the Mandr*, Debian and ex-Connectiva perl-base list
	# Then, I added several files to get GNU autotools running
	# FIXME: should this be in a separated file to be sourced?
	local MINIMAL_PERL_INSTALL="
	${bindir}/h2ph
	${bindir}/perl
	${bindir}/perl${MY_PV}
	${bindir}/pod2man
	${libdir}/${LIBPERL}
	${libdir}/libperl$(get_libname)
	${libdir}/libperl$(get_libname ${SHORT_PV})
	.${PRIV_LIB}/AutoLoader.pm
	.${PRIV_LIB}/B/Deparse.pm
	.${PRIV_LIB}/Carp.pm
	.${PRIV_LIB}/Carp/Heavy.pm
	.${PRIV_LIB}/Class/Struct.pm
	.${PRIV_LIB}/DirHandle.pm
	.${PRIV_LIB}/Exporter.pm
	.${PRIV_LIB}/Exporter/Heavy.pm
	.${PRIV_LIB}/ExtUtils/Command.pm
	.${PRIV_LIB}/ExtUtils/Command/MM.pm
	.${PRIV_LIB}/ExtUtils/Constant.pm
	.${PRIV_LIB}/ExtUtils/Constant/Base.pm
	.${PRIV_LIB}/ExtUtils/Constant/Utils.pm
	.${PRIV_LIB}/ExtUtils/Constant/XS.pm
	.${PRIV_LIB}/ExtUtils/Embed.pm
	.${PRIV_LIB}/ExtUtils/Install.pm
	.${PRIV_LIB}/ExtUtils/Installed.pm
	.${PRIV_LIB}/ExtUtils/Liblist.pm
	.${PRIV_LIB}/ExtUtils/Liblist/Kid.pm
	.${PRIV_LIB}/ExtUtils/MM.pm
	.${PRIV_LIB}/ExtUtils/MM_Any.pm
	.${PRIV_LIB}/ExtUtils/MM_MacOS.pm
	.${PRIV_LIB}/ExtUtils/MM_Unix.pm
	.${PRIV_LIB}/ExtUtils/MY.pm
	.${PRIV_LIB}/ExtUtils/MakeMaker.pm
	.${PRIV_LIB}/ExtUtils/MakeMaker/Config.pm
	.${PRIV_LIB}/ExtUtils/Manifest.pm
	.${PRIV_LIB}/ExtUtils/Miniperl.pm
	.${PRIV_LIB}/ExtUtils/Mkbootstrap.pm
	.${PRIV_LIB}/ExtUtils/Mksymlists.pm
	.${PRIV_LIB}/ExtUtils/Packlist.pm
	.${PRIV_LIB}/ExtUtils/testlib.pm
	.${PRIV_LIB}/File/Basename.pm
	.${PRIV_LIB}/File/Compare.pm
	.${PRIV_LIB}/File/Copy.pm
	.${PRIV_LIB}/File/Find.pm
	.${PRIV_LIB}/File/Path.pm
	.${PRIV_LIB}/File/stat.pm
	.${PRIV_LIB}/FileHandle.pm
	.${PRIV_LIB}/Getopt/Long.pm
	.${PRIV_LIB}/Getopt/Std.pm
	.${PRIV_LIB}/IPC/Open2.pm
	.${PRIV_LIB}/IPC/Open3.pm
	.${PRIV_LIB}/PerlIO.pm
	.${PRIV_LIB}/Pod/InputObjects.pm
	.${PRIV_LIB}/Pod/Man.pm
	.${PRIV_LIB}/Pod/ParseLink.pm
	.${PRIV_LIB}/Pod/Parser.pm
	.${PRIV_LIB}/Pod/Select.pm
	.${PRIV_LIB}/Pod/Text.pm
	.${PRIV_LIB}/Pod/Usage.pm
	.${PRIV_LIB}/SelectSaver.pm
	.${PRIV_LIB}/Symbol.pm
	.${PRIV_LIB}/Text/ParseWords.pm
	.${PRIV_LIB}/Text/Tabs.pm
	.${PRIV_LIB}/Text/Wrap.pm
	.${PRIV_LIB}/Tie/Hash.pm
	.${PRIV_LIB}/Time/Local.pm
	.${PRIV_LIB}/XSLoader.pm
	.${PRIV_LIB}/autouse.pm
	.${PRIV_LIB}/base.pm
	.${PRIV_LIB}/bigint.pm
	.${PRIV_LIB}/bignum.pm
	.${PRIV_LIB}/bigrat.pm
	.${PRIV_LIB}/blib.pm
	.${PRIV_LIB}/bytes.pm
	.${PRIV_LIB}/bytes_heavy.pl
	.${PRIV_LIB}/charnames.pm
	.${PRIV_LIB}/constant.pm
	.${PRIV_LIB}/diagnostics.pm
	.${PRIV_LIB}/fields.pm
	.${PRIV_LIB}/filetest.pm
	.${PRIV_LIB}/if.pm
	.${PRIV_LIB}/integer.pm
	.${PRIV_LIB}/less.pm
	.${PRIV_LIB}/locale.pm
	.${PRIV_LIB}/open.pm
	.${PRIV_LIB}/overload.pm
	.${PRIV_LIB}/sigtrap.pm
	.${PRIV_LIB}/sort.pm
	.${PRIV_LIB}/stat.pl
	.${PRIV_LIB}/strict.pm
	.${PRIV_LIB}/subs.pm
	.${PRIV_LIB}/unicore/To/Fold.pl
	.${PRIV_LIB}/unicore/To/Lower.pl
	.${PRIV_LIB}/unicore/To/Upper.pl
	.${PRIV_LIB}/utf8.pm
	.${PRIV_LIB}/utf8_heavy.pl
	.${PRIV_LIB}/vars.pm
	.${PRIV_LIB}/vmsish.pm
	.${PRIV_LIB}/warnings
	.${PRIV_LIB}/warnings.pm
	.${PRIV_LIB}/warnings/register.pm
	.${ARCH_LIB}/B.pm
	.${ARCH_LIB}/CORE/libperl$(get_libname)
	.${ARCH_LIB}/Config.pm
	.${ARCH_LIB}/Config_heavy.pl
	.${ARCH_LIB}/Cwd.pm
	.${ARCH_LIB}/Data/Dumper.pm
	.${ARCH_LIB}/DynaLoader.pm
	.${ARCH_LIB}/Errno.pm
	.${ARCH_LIB}/Fcntl.pm
	.${ARCH_LIB}/File/Glob.pm
	.${ARCH_LIB}/File/Spec.pm
	.${ARCH_LIB}/File/Spec/Unix.pm
	.${ARCH_LIB}/IO.pm
	.${ARCH_LIB}/IO/File.pm
	.${ARCH_LIB}/IO/Handle.pm
	.${ARCH_LIB}/IO/Pipe.pm
	.${ARCH_LIB}/IO/Seekable.pm
	.${ARCH_LIB}/IO/Select.pm
	.${ARCH_LIB}/IO/Socket.pm
	.${ARCH_LIB}/IO/Socket/INET.pm
	.${ARCH_LIB}/IO/Socket/UNIX.pm
	.${ARCH_LIB}/List/Util.pm
	.${ARCH_LIB}/NDBM_File.pm
	.${ARCH_LIB}/POSIX.pm
	.${ARCH_LIB}/Scalar/Util.pm
	.${ARCH_LIB}/Socket.pm
	.${ARCH_LIB}/Storable.pm
	.${ARCH_LIB}/attributes.pm
	.${ARCH_LIB}/auto/Cwd/Cwd$(get_libname)
	.${ARCH_LIB}/auto/Data/Dumper/Dumper$(get_libname)
	.${ARCH_LIB}/auto/DynaLoader/dl_findfile.al
	.${ARCH_LIB}/auto/Fcntl/Fcntl$(get_libname)
	.${ARCH_LIB}/auto/File/Glob/Glob$(get_libname)
	.${ARCH_LIB}/auto/IO/IO$(get_libname)
	.${ARCH_LIB}/auto/POSIX/POSIX$(get_libname)
	.${ARCH_LIB}/auto/POSIX/autosplit.ix
	.${ARCH_LIB}/auto/POSIX/fstat.al
	.${ARCH_LIB}/auto/POSIX/load_imports.al
	.${ARCH_LIB}/auto/POSIX/stat.al
	.${ARCH_LIB}/auto/POSIX/tmpfile.al
	.${ARCH_LIB}/auto/Socket/Socket$(get_libname)
	.${ARCH_LIB}/auto/Storable/Storable$(get_libname)
	.${ARCH_LIB}/auto/Storable/_retrieve.al
	.${ARCH_LIB}/auto/Storable/_store.al
	.${ARCH_LIB}/auto/Storable/autosplit.ix
	.${ARCH_LIB}/auto/Storable/retrieve.al
	.${ARCH_LIB}/auto/Storable/store.al
	.${ARCH_LIB}/auto/re/re$(get_libname)
	.${ARCH_LIB}/encoding.pm
	.${ARCH_LIB}/lib.pm
	.${ARCH_LIB}/ops.pm
	.${ARCH_LIB}/re.pm
	.${ARCH_LIB}/threads.pm
"

	pushd "${D}" > /dev/null
	# Remove cruft
	einfo "Removing files that are not in the minimal install"
	echo "${MINIMAL_PERL_INSTALL}"
	for f in $(find . -type f ) ; do
		has "${f}" ${MINIMAL_PERL_INSTALL} || rm -f "${f}"
	done
	# Remove empty directories
	find . -depth -type d -print0 | xargs -0 -r rmdir &> /dev/null
	#for f in ${MINIMAL_PERL_INSTALL} ; do
	#	[[ -e ${f} ]] || ewarn "${f} unused in MINIMAL_PERL_INSTALL"
	#done
	popd > /dev/null
}
