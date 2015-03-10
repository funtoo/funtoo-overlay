# Distributed under the terms of the GNU General Public License v2

EAPI="5"

inherit eutils flag-o-matic multilib pam toolchain-funcs

DESCRIPTION="OpenRC manages the services, startup and shutdown of a host"
HOMEPAGE="http://roy.marples.name/openrc"
RESTRICT="mirror"

LICENSE="BSD-2"
SLOT="0"
KEYWORDS="*"
IUSE="debug elibc_glibc ncurses pam selinux static-libs unicode kernel_linux kernel_FreeBSD"

RDEPEND="kernel_linux? ( >=sys-apps/sysvinit-2.86-r11 )
	kernel_FreeBSD? ( sys-process/fuser-bsd )
	pam? ( virtual/pam )
	>=sys-apps/baselayout-2.2
	sys-apps/iproute2"

DEPEND="ncurses? ( sys-libs/ncurses ) pam? ( virtual/pam ) virtual/os-headers virtual/pkgconfig"

GITHUB_REPO="${PN}"
GITHUB_USER="funtoo"
GITHUB_TAG="funtoo-openrc-0.12.3-r2"
NETV="1.3.9.1"
GITHUB_REPO_CN="corenetwork"
GITHUB_TAG_CN="$NETV"

SRC_URI="
	https://www.github.com/${GITHUB_USER}/${GITHUB_REPO}/tarball/${GITHUB_TAG} -> ${PN}-${GITHUB_TAG}.tar.gz
	https://www.github.com/${GITHUB_USER}/${GITHUB_REPO_CN}/tarball/${GITHUB_TAG_CN} -> corenetwork-${NETV}.tar.gz
	"

make_args() {
	unset LIBDIR #266688

	MAKE_ARGS="${MAKE_ARGS} LIBNAME=$(get_libdir) LIBEXECDIR=/$(get_libdir)/rc MKNET=no"

	local brand="Unknown"
	if use kernel_linux ; then
		MAKE_ARGS="${MAKE_ARGS} OS=Linux"
		brand="Linux"
	elif use kernel_FreeBSD ; then
		MAKE_ARGS="${MAKE_ARGS} OS=FreeBSD"
		brand="FreeBSD"
	fi
	if use selinux; then
			MAKE_ARGS="${MAKE_ARGS} MKSELINUX=yes"
	fi
	export BRANDING="Funtoo ${brand}"
	if ! use static-libs; then
			MAKE_ARGS="${MAKE_ARGS} MKSTATICLIBS=no"
	fi
}

pkg_setup() {
	export DEBUG=$(usev debug)
	export MKPAM=$(usev pam)
	export MKTERMCAP=$(usev ncurses)
}

src_unpack() {
	unpack $A
	# rename github directories to the names we're expecting:
	local old=${WORKDIR}/${GITHUB_USER}-${PN}-*
	mv $old "${WORKDIR}/${P}" || die "move fail 1"
	old="${WORKDIR}/${GITHUB_USER}-corenetwork-*"
	mv $old "${WORKDIR}/corenetwork-${NETV}" || die "move fail 2"
}

src_prepare() {
	sed -i 's:0444:0644:' mk/sys.mk || die

	if [[ ${PV} == "9999" ]] ; then
		local ver="git-${EGIT_VERSION:0:6}"
		sed -i "/^GITVER[[:space:]]*=/s:=.*:=${ver}:" mk/git.mk || die
	fi
	epatch "${FILESDIR}/fix-openvz-r1.patch"
}
src_compile() {
	make_args

	tc-export CC AR RANLIB
	emake ${MAKE_ARGS}
}

# set_config <file> <option name> <yes value> <no value> test
# a value of "#" will just comment out the option
set_config() {
	local file="${D}/$1" var=$2 val com
	eval "${@:5}" && val=$3 || val=$4
	[[ ${val} == "#" ]] && com="#" && val='\2'
	sed -i -r -e "/^#?${var}=/{s:=([\"'])?([^ ]*)\1?:=\1${val}\1:;s:^#?:${com}:}" "${file}"
}

set_config_yes_no() {
	set_config "$1" "$2" YES NO "${@:3}"
}

src_install() {
	make_args
	emake ${MAKE_ARGS} DESTDIR="${D}" install

	# move the shared libs back to /usr so ldscript can install
	# more of a minimal set of files
	# disabled for now due to #270646
	#mv "${D}"/$(get_libdir)/lib{einfo,rc}* "${D}"/usr/$(get_libdir)/ || die
	#gen_usr_ldscript -a einfo rc
	gen_usr_ldscript libeinfo.so
	gen_usr_ldscript librc.so

	if ! use kernel_linux; then
		keepdir /$(get_libdir)/rc/init.d
	fi
	keepdir /$(get_libdir)/rc/tmp

	# Backup our default runlevels
	dodir /usr/share/"${PN}"
	cp -PR "${D}"/etc/runlevels "${D}"/usr/share/${PN} || die
	rm -rf "${D}"/etc/runlevels

	# Setup unicode defaults for silly unicode users
	set_config_yes_no /etc/rc.conf unicode use unicode

	# Cater to the norm
	set_config_yes_no /etc/conf.d/keymaps windowkeys '(' use x86 '||' use amd64 ')'

	# On HPPA, do not run consolefont by default (bug #222889)
	if use hppa; then
		rm -f "${D}"/usr/share/openrc/runlevels/boot/consolefont
	fi

	# Support for logfile rotation
	insinto /etc/logrotate.d
	newins "${FILESDIR}"/openrc.logrotate openrc

	# install the gentoo pam.d file
	newpamd "${FILESDIR}"/start-stop-daemon.pam start-stop-daemon

	# Install funtoo networking parts:

	cd ${WORKDIR}/corenetwork-${NETV} || die
	dodoc docs/index.rst || die
	exeinto /etc/init.d || die
	doexe init.d/{netif.tmpl,netif.lo} || die
	cp -a netif.d ${D}/etc || die
	chown -R root:root ${D}/etc/netif.d || die
	chmod 0755 ${D}/etc/netif.d || die
	chmod -R 0644 ${D}/etc/netif.d/* || die
	ln -s /etc/init.d/netif.lo ${D}/usr/share/openrc/runlevels/sysinit/netif.lo || die
}

add_init() {
	local runl=$1
	shift
	if [ ! -e ${ROOT}/etc/runlevels/${runl} ]
	then
		install -d -m0755 ${ROOT}/etc/runlevels/${runl}
	fi
	for initd in $*
	do
		[[ -e ${ROOT}/etc/runlevels/${runl}/${initd} ]] && continue
		elog "Auto-adding '${initd}' service to your ${runl} runlevel"
		ln -snf /etc/init.d/${initd} "${ROOT}"/etc/runlevels/${runl}/${initd}
	done
}

pkg_postinst() {
	local runl
	install -d -m0755 ${ROOT}/etc/runlevels
	local runldir="${ROOT}usr/share/openrc/runlevels"

	# Remove old baselayout links
	rm -f "${ROOT}"/etc/runlevels/boot/{check{fs,root},rmnologin}
	rm -f "${ROOT}"/etc/init.d/{depscan,runscript}.sh
	rm -f "${ROOT}"/etc/runlevels/boot/netif.lo

	# CREATE RUNLEVEL DIRECTORIES
	# ===========================

	# To ensure proper system operation, this portion of the script ensures that
	# all of OpenRC's default initscripts in all runlevels are properly
	# installed.

	for runl in $( cd "$runldir"; echo * )
	do
		einfo "Processing $runl..."
		einfo "Ensuring runlevel $runl has all required scripts..."
		add_init $runl $( cd "$runldir/$runl"; echo * )
	done

	# Rather than try to migrate everyone using complex scripts, simply print
	# names of initscripts that are in the user's runlevels but not provided by
	# OpenRC. This loop can be upgraded to look for particular scripts that
	# might have come from baselayout.

	for runl in $( cd ${ROOT}/etc/runlevels; echo * )
	do
		[ ! -d ${runldir}/${runl} ] && continue
		for init in $( cd "$runldir/$runl"; echo * )
		do
			if [ -e ${ROOT}/etc/runlevels/${runl}/${init} ] && [ ! -e ${runldir}/${runl}/${init} ]
			then
				echo "Initscript ${init} exists in runlevel ${runl} but not in OpenRC."
			fi
		done
	done

	chmod +x ${ROOT}/etc/netif.d

	# OTHER STUFF
	# ===========

	# update the dependency tree bug #224171
	[[ "${ROOT}" = "/" ]] && "${ROOT}/$(get_libdir)"/rc/bin/rc-depend -u

	elog "You should now update all files in /etc, using etc-update"
	elog "or equivalent before rebooting."
	elog

	if path_exists -o "${ROOT}"/etc/conf.d/local.{start,stop} ; then
		ewarn "/etc/conf.d/local.{start,stop} are deprecated.  Please convert"
		ewarn "your files to /etc/conf.d/local and delete the files."
	fi

	ewarn "Make sure that correct symlink exist"
	ewarn "Re-establish it by ln -s /etc/init.d/netif.tmpl /etc/init.d/netif.ethX"
}
