# Distributed under the terms of the GNU General Public License v2

EAPI=5

inherit eutils flag-o-matic multilib pam toolchain-funcs

DESCRIPTION="OpenRC manages the services, startup and shutdown of a host"
HOMEPAGE="https://www.gentoo.org/proj/en/base/openrc/"

if [[ ${PV} == "9999" ]]; then
	EGIT_REPO_URI="git://github.com/OpenRC/${PN}.git"
	inherit git-r3
else
	SRC_URI="https://dev.gentoo.org/~williamh/dist/${P}.tar.bz2"
	KEYWORDS="*"
fi

LICENSE="BSD-2"
SLOT="0"
IUSE="audit debug elibc_glibc ncurses pam newnet prefix -netifrc selinux static-libs
	tools unicode kernel_linux kernel_FreeBSD"

COMMON_DEPEND="kernel_FreeBSD? ( || ( >=sys-freebsd/freebsd-ubin-9.0_rc sys-process/fuser-bsd ) )
	elibc_glibc? ( >=sys-libs/glibc-2.5 )
	ncurses? ( sys-libs/ncurses:0= )
	pam? (
		sys-auth/pambase
		virtual/pam
	)
	tools? ( dev-lang/perl )
	audit? ( sys-process/audit )
	kernel_linux? (
		sys-process/psmisc
		!<sys-process/procps-3.3.9-r2
	)
	selinux? (
		sys-apps/policycoreutils
		sys-libs/libselinux
	)
	!<sys-apps/baselayout-2.1-r1
	!<sys-fs/udev-init-scripts-27"
DEPEND="${COMMON_DEPEND}
	virtual/os-headers
	ncurses? ( virtual/pkgconfig )"
RDEPEND="${COMMON_DEPEND}
	>=sys-apps/corenetwork-1.5.4
	!prefix? (
		kernel_linux? ( || ( >=sys-apps/sysvinit-2.86-r6 sys-process/runit ) )
		kernel_FreeBSD? ( sys-freebsd/freebsd-sbin )
	)
	selinux? (
		sec-policy/selinux-base-policy
		sec-policy/selinux-openrc
	)
"

PDEPEND="netifrc? ( net-misc/netifrc )"

src_prepare() {
	sed -i 's:0444:0644:' mk/sys.mk || die

	if [[ ${PV} == "9999" ]] ; then
		local ver="git-${EGIT_VERSION:0:6}"
		sed -i "/^GITVER[[:space:]]*=/s:=.*:=${ver}:" mk/gitver.mk || die
	fi

	# Allow user patches to be applied without modifying the ebuild
	epatch_user
}

src_compile() {
	unset LIBDIR #266688

	MAKE_ARGS="${MAKE_ARGS}
		LIBNAME=$(get_libdir)
		LIBEXECDIR=${EPREFIX}/$(get_libdir)/rc
		MKNET=$(usex newnet)
		MKSELINUX=$(usex selinux)
		MKAUDIT=$(usex audit)
		MKPAM=$(usev pam)
		MKSTATICLIBS=$(usex static-libs)
		MKTOOLS=$(usex tools)"

	local brand="Unknown"
	if use kernel_linux ; then
		MAKE_ARGS="${MAKE_ARGS} OS=Linux"
		brand="Linux"
	elif use kernel_FreeBSD ; then
		MAKE_ARGS="${MAKE_ARGS} OS=FreeBSD"
		brand="FreeBSD"
	fi
	export BRANDING="Funtoo ${brand}"
	use prefix && MAKE_ARGS="${MAKE_ARGS} MKPREFIX=yes PREFIX=${EPREFIX}"
	export DEBUG=$(usev debug)
	export MKTERMCAP=$(usev ncurses)

	tc-export CC AR RANLIB
	emake ${MAKE_ARGS}
}

# set_config <file> <option name> <yes value> <no value> test
# a value of "#" will just comment out the option
set_config() {
	local file="${ED}/$1" var=$2 val com
	eval "${@:5}" && val=$3 || val=$4
	[[ ${val} == "#" ]] && com="#" && val='\2'
	sed -i -r -e "/^#?${var}=/{s:=([\"'])?([^ ]*)\1?:=\1${val}\1:;s:^#?:${com}:}" "${file}"
}

set_config_yes_no() {
	set_config "$1" "$2" YES NO "${@:3}"
}

src_install() {
	emake ${MAKE_ARGS} DESTDIR="${D}" install

	# move the shared libs back to /usr so ldscript can install
	# more of a minimal set of files
	# disabled for now due to #270646
	#mv "${ED}"/$(get_libdir)/lib{einfo,rc}* "${ED}"/usr/$(get_libdir)/ || die
	#gen_usr_ldscript -a einfo rc
	gen_usr_ldscript libeinfo.so
	gen_usr_ldscript librc.so

	if ! use kernel_linux; then
		keepdir /$(get_libdir)/rc/init.d
	fi
	keepdir /$(get_libdir)/rc/tmp

	# Backup our default runlevels
	dodir /usr/share/"${PN}"
	cp -PR "${ED}"/etc/runlevels "${ED}"/usr/share/${PN} || die
	rm -rf "${ED}"/etc/runlevels

	# Setup unicode defaults for silly unicode users
	set_config_yes_no /etc/rc.conf unicode use unicode

	# Cater to the norm
	set_config_yes_no /etc/conf.d/keymaps windowkeys '(' use x86 '||' use amd64 ')'

	# On HPPA, do not run consolefont by default (bug #222889)
	if use hppa; then
		rm -f "${ED}"/usr/share/openrc/runlevels/boot/consolefont
	fi

	# Support for logfile rotation
	insinto /etc/logrotate.d
	newins "${FILESDIR}"/openrc.logrotate openrc

	# install the gentoo pam.d file
	newpamd "${FILESDIR}"/start-stop-daemon.pam start-stop-daemon

	# install documentation
	dodoc ChangeLog *.md
	if use newnet; then
		dodoc README.newnet
	fi

	# funtoo goodies
	exeinto /etc/init.d
	doexe "$FILESDIR/hostname"
	doexe "$FILESDIR/loopback"

	insinto /etc/conf.d
	newins "$FILESDIR/hostname.confd" hostname
}

pkg_preinst() {
	local f LIBDIR=$(get_libdir)

	# set default interactive shell to sulogin if it exists
	set_config /etc/rc.conf rc_shell /sbin/sulogin "#" test -e /sbin/sulogin
}

pkg_postinst() {
	local LIBDIR=$(get_libdir)

	echo
	for r in sysinit boot shutdown; do
		# install missing scripts
		for sc in $(cd ${EROOT}/usr/share/openrc/runlevels/$r; ls); do
			if [ ! -L ${EROOT}/etc/runlevels/$r/$sc ]; then
				einfo "Missing $r/$sc script, installing..."
				cp -a ${EROOT}/usr/share/openrc/runlevels/$r/$sc ${EROOT}/etc/runlevels/$r/$sc
			fi
		done
		# warn about extra scripts
		for sc in $(cd ${EROOT}/etc/runlevels/$r; ls); do
			if [ "$sc" == "netif.lo" ]; then
				einfo "Removing old initscript netif.lo."
				rm ${EROOT}/etc/runlevels/$r/$sc
			elif [ ! -e ${EROOT}/etc/runlevels/$r/$sc ]; then
				einfo "Removing broken symlink for initscript in runlevel $r/$sc"
				rm ${EROOT}/etc/runlevels/$r/$sc
			fi
			if [ ! -L ${EROOT}/usr/share/openrc/runlevels/$r/$sc ]; then
				ewarn "Extra script $r/$sc found, possibly from other ebuild."
			fi
		done
	done
	echo

	# Handle the conf.d/local.{start,stop} -> local.d transition
	if path_exists -o "${EROOT}"etc/conf.d/local.{start,stop} ; then
		elog "Moving your ${EROOT}etc/conf.d/local.{start,stop}"
		elog "files to ${EROOT}etc/local.d"
		mv "${EROOT}"etc/conf.d/local.start "${EROOT}"etc/local.d/baselayout1.start
		mv "${EROOT}"etc/conf.d/local.stop "${EROOT}"etc/local.d/baselayout1.stop
		chmod +x "${EROOT}"etc/local.d/*{start,stop}
	fi

	if use kernel_linux && [[ "${EROOT}" = "/" ]]; then
		if ! /$(get_libdir)/rc/sh/migrate-to-run.sh; then
			ewarn "The dependency data could not be migrated to /run/openrc."
			ewarn "This means you need to reboot your system."
		fi
	fi

	# update the dependency tree after touching all files #224171
	[[ "${EROOT}" = "/" ]] && "${EROOT}/${LIBDIR}"/rc/bin/rc-depend -u

	# Updated for 0.13.2.
	echo
	ewarn "Bug https://bugs.gentoo.org/show_bug.cgi?id=427996 was not"
	ewarn "fixed correctly in earlier versions of OpenRC."
	ewarn "The correct fix is implemented in this version, but that"
	ewarn "means netmount needs to be added to the default runlevel if"
	ewarn "you are using nfs file systems."
	ewarn

	elog "You should now update all files in /etc, using etc-update"
	elog "or equivalent before restarting any services or this host."
}
