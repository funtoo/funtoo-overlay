# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=3
inherit eutils multilib toolchain-funcs autotools linux-info

DESCRIPTION="User-land utilities for LVM2 (device-mapper) software."
HOMEPAGE="http://sources.redhat.com/lvm2/"
SRC_URI="ftp://sources.redhat.com/pub/lvm2/${PN/lvm/LVM}.${PV}.tgz
		 ftp://sources.redhat.com/pub/lvm2/old/${PN/lvm/LVM}.${PV}.tgz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"

IUSE="readline +static +static-libs clvm cman +lvm1 selinux"

DEPEND_COMMON="!!sys-fs/device-mapper
	readline? ( sys-libs/readline )
	clvm? ( =sys-cluster/dlm-2*
			cman? ( =sys-cluster/cman-2* ) )
	>=sys-fs/udev-151-r4"

RDEPEND="${DEPEND_COMMON}
	!<sys-apps/openrc-0.4
	!!sys-fs/lvm-user
	!!sys-fs/clvm
	>=sys-apps/util-linux-2.16"

# Upgrading to this LVM will break older cryptsetup
RDEPEND="${RDEPEND}
		!<sys-fs/cryptsetup-1.1.2"

DEPEND="${DEPEND_COMMON}
		dev-util/pkgconfig
		>=sys-devel/binutils-2.20.1"

S="${WORKDIR}/${PN/lvm/LVM}.${PV}"

MYDIR="$FILESDIR/2.02.88"

pkg_setup() {
	local CONFIG_CHECK="~SYSVIPC"
	local WARNING_SYSVIPC="CONFIG_SYSVIPC:\tis not set (required for udev sync)\n"
	check_extra_config
	# 1. Genkernel no longer copies /sbin/lvm blindly.
	# 2. There are no longer any linking deps in /usr.
	if use static; then
		elog "Warning, we no longer overwrite /sbin/lvm and /sbin/dmsetup with"
		elog "their static versions. If you need the static binaries,"
		elog "you must append .static to the filename!"
	fi
}

src_unpack() {
	unpack ${A}
}

src_prepare() {
	epatch ${MYDIR}/lvm.conf-2.02.67.patch
	epatch ${MYDIR}/${PN}-2.02.63-always-make-static-libdm.patch
	epatch ${MYDIR}/lvm2-2.02.56-lvm2create_initrd.patch
	# bug 318513
	epatch ${MYDIR}/${PN}-2.02.64-dmeventd-libs.patch
	# bug 301331
	epatch ${MYDIR}/${PN}-2.02.67-createinitrd.patch
	# bug 330373
	epatch ${MYDIR}/${PN}-2.02.73-locale-muck.patch
	# --as-needed
	epatch ${MYDIR}/${PN}-2.02.70-asneeded.patch
	# bug 332905
	epatch ${MYDIR}/${PN}-2.02.72-dynamic-static-ldflags.patch
	eautoreconf
}

src_configure() {
	local myconf
	local buildmode

	myconf="${myconf} --enable-dmeventd"
	myconf="${myconf} --enable-cmdlib"
	myconf="${myconf} --enable-applib"
	myconf="${myconf} --enable-fsadm"

	# Most of this package does weird stuff.
	# The build options are tristate, and --without is NOT supported
	# options: 'none', 'internal', 'shared'
	if use static ; then
		einfo "Building static LVM, for usage inside genkernel"
		buildmode="internal"
		# This only causes the .static versions to become available
		# For recent systems, there are no linkages against anything in /usr anyway.
		# We explicitly provide the .static versions so that they can be included in
		# initramfs environments.
		myconf="${myconf} --enable-static_link"
	else
		ewarn "Building shared LVM, it will not work inside genkernel!"
		buildmode="shared"
	fi

	# dmeventd requires mirrors to be internal, and snapshot available
	# so we cannot disable them
	myconf="${myconf} --with-mirrors=internal"
	myconf="${myconf} --with-snapshots=internal"

	if use lvm1 ; then
		myconf="${myconf} --with-lvm1=${buildmode}"
	else
		myconf="${myconf} --with-lvm1=none"
	fi

	# disable O_DIRECT support on hppa, breaks pv detection (#99532)
	use hppa && myconf="${myconf} --disable-o_direct"

	if use clvm; then
		myconf="${myconf} --with-cluster=${buildmode}"
		# 4-state! Make sure we get it right, per bug 210879
		# Valid options are: none, cman, gulm, all
		#
		# 2009/02:
		# gulm is removed now, now dual-state:
		# cman, none
		# all still exists, but is not needed
		#
		# 2009/07:
		# TODO: add corosync and re-enable ALL
		local clvmd=""
		use cman && clvmd="cman"
		#clvmd="${clvmd/cmangulm/all}"
		[ -z "${clvmd}" ] && clvmd="none"
		myconf="${myconf} --with-clvmd=${clvmd}"
		myconf="${myconf} --with-pool=${buildmode}"
	else
		myconf="${myconf} --with-clvmd=none --with-cluster=none"
	fi

	myconf="${myconf}
			--with-dmeventd-path=/sbin/dmeventd"
	econf $(use_enable readline) \
		$(use_enable selinux) \
		--enable-pkgconfig \
		--with-confdir="${EPREFIX}/etc" \
		--sbindir="${EPREFIX}/sbin" \
		--with-staticdir="${EPREFIX}/sbin" \
		--libdir="${EPREFIX}/$(get_libdir)" \
		--with-usrlibdir="${EPREFIX}/usr/$(get_libdir)" \
		--enable-udev_rules \
		--enable-udev_sync \
		--with-udevdir="${EPREFIX}/lib/udev/rules.d/" \
		${myconf} \
		CLDFLAGS="${LDFLAGS}" || die
}

src_compile() {
	einfo "Doing symlinks"
	pushd include
	emake || die "Failed to prepare symlinks"
	popd

	einfo "Starting main build"
	emake || die "compile fail"
}

src_install() {
	emake DESTDIR="${D}" install || die "Failed to emake install"

	# missing goodies:

	dosbin "${S}"/scripts/lvm2create_initrd/lvm2create_initrd || die
	doman  "${S}"/scripts/lvm2create_initrd/lvm2create_initrd.8 || die
	newdoc "${S}"/scripts/lvm2create_initrd/README README.lvm2create_initrd || die

	# docs:

	dodoc README VERSION* WHATS_NEW WHATS_NEW_DM doc/*.{conf,c,txt}

	# For now, we are deprecating dmtab until a man page can be provided for it.

	# the following add-ons are used by the initscripts:

	insinto /$(get_libdir)/rcscripts/addons
	for addon in lvm-start lvm-stop dm-start
	do
		doins "${MYDIR}/${addon}.sh" || die
	done

	# install initscripts and corresponding conf.d files:

	local inits="lvm device-mapper dmeventd lvm-monitoring"
	use clvm && inits="$inits clvmd"

	for rc in $inits
	do
		newinitd "${MYDIR}/${rc}.rc" ${rc} || die
		if [ -e "${MYDIR}/${rc}.confd" ]
		then
			newconfd "${MYDIR}/${rc}.confd" ${rc} || die
		fi
	done

	# move shared libs to /lib(64)
	if use static-libs; then
		dolib.a libdm/ioctl/libdevmapper.a || die "dolib.a libdevmapper.a"
		dolib.a daemons/dmeventd/libdevmapper-event.a || die "dolib.a libdevmapper-event.a"
	else
		rm -f "${D}"/usr/$(get_libdir)/{libdevmapper-event,liblvm2cmd,liblvm2app,libdevmapper}.a
	fi

	# do not rely on /lib -> /libXX link

	sed -e "s-/lib/rcscripts/-/$(get_libdir)/rcscripts/-" -i "${ED}"/etc/init.d/*

	elog "USE flag nocman is deprecated and replaced with the cman USE flag."
	elog ""
	elog "USE flags clvm and cman are masked by default and need to be unmasked to be used."
	elog ""
	elog "If you are using genkernel and root-on-LVM, rebuild the initramfs to use this new lvm2."
}

add_init() {
	local runl=$1
	shift
	if [ ! -e ${ROOT}etc/runlevels/${runl} ]
	then
		install -d -m0755 ${ROOT}etc/runlevels/${runl}
	fi
	for initd in $*
	do
		einfo "Auto-adding '${initd}' service to your ${runl} runlevel"
		[[ -e ${ROOT}etc/runlevels/${runl}/${initd} ]] && continue
		[[ ! -e ${ROOT}etc/init.d/${initd} ]] && die "initscript $initd not found; aborting"
		ln -snf /etc/init.d/${initd} "${ROOT}etc/runlevels/${runl}/${initd}"
	done
}

pkg_postinst() {
	if use rc_enable; then
		einfo
		add_init boot device-mapper lvm
		einfo
		einfo "Type \"rc\" to enable new services."
		echo
	else
		elog "lvm volume detection has not been automatically enabled. To enable at boot,"
		elog "add device-mapper and lvm to your boot runlevel:"
		elog
		elog "# rc-update add device-mapper boot"
		elog "# rc-update add lvm boot"
	fi
}

src_test() {
	einfo "Testcases disabled because of device-node mucking"
	einfo "If you want them, compile the package and see ${S}/tests"
}
