# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-boot/grub/grub-0.97-r9.ebuild,v 1.5 2009/07/04 18:46:05 robbat2 Exp $

# XXX: we need to review menu.lst vs grub.conf handling.  We've been converting
#      all systems to grub.conf (and symlinking menu.lst to grub.conf), but
#      we never updated any of the source code (it still all wants menu.lst),
#      and there is no indication that upstream is making the transition.

inherit mount-boot eutils flag-o-matic toolchain-funcs autotools
RPN=grub
RP=${RPN}-${PV}
S=${WORKDIR}/${RP}

PATCHVER="1.12" # Should match the revision ideally
DESCRIPTION="GNU GRUB Legacy boot loader"
HOMEPAGE="http://www.gnu.org/software/grub/"
SRC_URI="mirror://gentoo/${RP}.tar.gz
	ftp://alpha.gnu.org/gnu/${RPN}/${RP}.tar.gz
	mirror://gentoo/splash.xpm.gz
	mirror://gentoo/${RP}-patches-${PATCHVER}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 x86"
IUSE="custom-cflags ncurses netboot static"

DEPEND="ncurses? (
		>=sys-libs/ncurses-5.2-r5
		amd64? ( app-emulation/emul-linux-x86-baselibs )
	)"
RDEPEND="$DEPEND"
PROVIDE="virtual/bootloader"

src_unpack() {
	unpack ${A}
	cd "${S}"

	# patch breaks booting for some people #111885
	rm "${WORKDIR}"/patch/400_*

	# Grub will not handle a kernel larger than EXTENDED_MEMSIZE Mb as
	# discovered in bug 160801. We can change this, however, using larger values
	# for this variable means that Grub needs more memory to run and boot. For a
	# kernel of size N, Grub needs (N+1)*2.  Advanced users should set a custom
	# value in make.conf, it is possible to make kernels ~16Mb in size, but it
	# needs the kitchen sink built-in.
	local t="custom"
	if [[ -z ${GRUB_MAX_KERNEL_SIZE} ]] ; then
		case $(tc-arch) in
			amd64) GRUB_MAX_KERNEL_SIZE=7 ;;
			x86)   GRUB_MAX_KERNEL_SIZE=3 ;;
		esac
		t="default"
	fi
	einfo "Grub will support the ${t} maximum kernel size of ${GRUB_MAX_KERNEL_SIZE} Mb (GRUB_MAX_KERNEL_SIZE)"

	sed -i \
		-e "/^#define.*EXTENDED_MEMSIZE/s,3,${GRUB_MAX_KERNEL_SIZE},g" \
		"${S}"/grub/asmstub.c \
		|| die "Failed to hack memory size"

	if [[ -n ${PATCHVER} ]] ; then
		EPATCH_SUFFIX="patch"
		epatch "${WORKDIR}"/patch
	fi

	cat ${FILESDIR}/${PVR}/grub-legacy-0.97-r12-device-map.patch | patch -p1 || die "patch failure"
	cat ${FILESDIR}/${PVR}/grub-legacy-0.97-r12-setup.patch | patch -p1 || die "patch failure"

	eautoreconf

	cat configure | sed -e "s:PACKAGE='grub':PACKAGE='grub-legacy':g" > configure.new
	cat configure.new > configure || die "legacy configure tweak failure"

}

src_compile() {
	filter-flags -fPIE #168834

	use amd64 && multilib_toolchain_setup x86

	unset BLOCK_SIZE #73499

	### i686-specific code in the boot loader is a bad idea; disabling to ensure
	### at least some compatibility if the hard drive is moved to an older or
	### incompatible system.

	# grub-0.95 added -fno-stack-protector detection, to disable ssp for stage2,
	# but the objcopy's (faulty) test fails if -fstack-protector is default.
	# create a cache telling configure that objcopy is ok, and add -C to econf
	# to make use of the cache.
	#
	# CFLAGS has to be undefined running econf, else -fno-stack-protector detection fails.
	# STAGE2_CFLAGS is not allowed to be used on emake command-line, it overwrites
	# -fno-stack-protector detected by configure, removed from netboot's emake.
	use custom-cflags || unset CFLAGS

	export grub_cv_prog_objcopy_absolute=yes #79734
	use static && append-ldflags -static

	# Per bug 216625, the emul packages do not provide .a libs for performing
	# suitable static linking
	if use amd64 && use static ; then
		if [ -z "${GRUB_STATIC_PACKAGE_BUILDING}" ]; then
			die "You must use the grub-static package if you want a static Grub on amd64!"
		else
			eerror "You have set GRUB_STATIC_PACKAGE_BUILDING. This"
			eerror "is specifically intended for building the tarballs for the"
			eerror "grub-static package via USE='static -ncurses'."
			eerror "All bets are now off."
			ebeep 10
		fi
	fi

	# build the net-bootable grub first, but only if "netboot" is set
	if use netboot ; then
		econf \
		--libdir=/lib \
		--datadir=/usr/lib/grub-legacy \
		--exec-prefix=/ \
		--disable-auto-linux-mem-opt \
		--enable-diskless \
		--enable-{3c{5{03,07,09,29,95},90x},cs89x0,davicom,depca,eepro{,100}} \
		--enable-{epic100,exos205,ni5210,lance,ne2100,ni{50,65}10,natsemi} \
		--enable-{ne,ns8390,wd,otulip,rtl8139,sis900,sk-g16,smc9000,tiara} \
		--enable-{tulip,via-rhine,w89c840} || die "netboot econf failed"

		emake w89c840_o_CFLAGS="-O" || die "making netboot stuff"

		mv -f stage2/{nbgrub,pxegrub} "${S}"/
		mv -f stage2/stage2 stage2/stage2.netboot

		make clean || die "make clean failed"
	fi

	# Now build the regular grub
	# Note that FFS and UFS2 support are broken for now - stage1_5 files too big
	econf \
		--libdir=/lib \
		--datadir=/usr/lib/grub-legacy \
		--program-suffix=-legacy \
		--exec-prefix=/ \
		--disable-auto-linux-mem-opt \
		$(use_with ncurses curses) \
		|| die "econf failed"

	# sanity check due to common failure
	use ncurses && ! grep -qs "HAVE_LIBCURSES.*1" config.h && die "USE=ncurses but curses not found"

	emake || die "making regular stuff"
}

src_test() {
	# non-default block size also give false pass/fails.
	unset BLOCK_SIZE
	make check || die "make check failed"
}

src_install() {
	emake DESTDIR="${D}" install || die
	if use netboot ; then
		exeinto /usr/lib/grub-legacy/${CHOST}
		doexe nbgrub pxegrub stage2/stage2.netboot || die "netboot install"
	fi

	dodoc AUTHORS BUGS ChangeLog NEWS README THANKS TODO
	prepalldocs

	[ -n "${GRUB_STATIC_PACKAGE_BUILDING}" ] && \
		mv \
		"${D}"/usr/share/doc/${PF} \
		"${D}"/usr/share/doc/grub-legacy-static-${PF/grub-}

	insinto /usr/share/grub-legacy
	doins "${DISTDIR}"/splash.xpm.gz
	mv ${D}/usr/share/info/grub.info ${D}/usr/share/info/grub-legacy.info || die "owie"

	dosed '/.*=${sbindir}/s:\(^.*$\):\1-legacy:g' /sbin/grub-install-legacy && \
	dosed '/^grubdir=.*\/grub$/s:\(^.*$\):\1-legacy:g' /sbin/grub-install-legacy && \
	dosed '/.*grub_prefix=/s:\(^.*\)grub\(.*$\):\1grub-legacy\2:g' /sbin/grub-install-legacy
	[ $? -ne 0 ] && die "dosed error"
}

setup_boot_dir() {
	local boot_dir=$1
	local dir=${boot_dir}

	mkdir -p "${dir}"
	[[ ! -L ${dir}/boot ]] && ln -s . "${dir}/boot"
	dir="${dir}/grub-legacy"
	if [[ ! -e ${dir} ]] ; then
		mkdir "${dir}" || die "${dir} does not exist!"
	fi

	# change menu.lst to grub.conf
	if [[ ! -e ${dir}/grub.conf ]] && [[ -e ${dir}/menu.lst ]] ; then
		mv -f "${dir}"/menu.lst "${dir}"/grub.conf
		ewarn
		ewarn "*** IMPORTANT NOTE: menu.lst has been renamed to grub.conf"
		ewarn
	fi

	if [[ ! -e ${dir}/menu.lst ]]; then
		einfo "Linking from new grub.conf name to menu.lst"
		ln -snf grub.conf "${dir}"/menu.lst
	fi

	if [[ -e ${dir}/stage2 ]] ; then
		mv "${dir}"/stage2{,.old}
		ewarn "*** IMPORTANT NOTE: you must run grub and install"
		ewarn "the new version's stage1 to your MBR.  Until you do,"
		ewarn "stage1 and stage2 will still be the old version, but"
		ewarn "later stages will be the new version, which could"
		ewarn "cause problems such as an unbootable system."
		ewarn "This means you must use either grub-install or perform"
		ewarn "root/setup manually! For more help, see the handbook:"
		ewarn "http://www.gentoo.org/doc/en/handbook/handbook-${ARCH}.xml?part=1&chap=10#grub-install-auto"
		ebeep
	fi

	einfo "Copying files from /lib/grub-legacy to ${dir}"
	for x in "${ROOT}"/lib*/grub-legacy/*/*; do
		[[ -f ${x} ]] && cp -p "${x}" "${dir}"/
	done

	# the grub default commands silently piss themselves if
	# the default file does not exist ahead of time
	if [[ ! -e ${dir}/default ]] && [[ -e /sbin/grub-set-default-legacy ]] ; then
		grub-set-default-legacy --root-directory="${boot_dir}" default
	fi
	einfo "Grub has been installed to ${boot_dir} successfully."
}

pkg_postinst() {
	if [[ -n ${DONT_MOUNT_BOOT} ]]; then
		elog "WARNING: you have DONT_MOUNT_BOOT in effect, so you must apply"
		elog "the following instructions for your /boot!"
		elog "Neglecting to do so may cause your system to fail to boot!"
		elog
	else
		setup_boot_dir "${ROOT}"/boot
		# Trailing output because if this is run from pkg_postinst, it gets mixed into
		# the other output.
		einfo ""
	fi
	elog "To interactively install grub files to another device such as a USB"
	elog "stick, just run the following and specify the directory as prompted:"
	elog "   emerge --config =${PF}"
	elog "Alternately, you can export GRUB_ALT_INSTALLDIR=/path/to/use to tell"
	elog "grub where to install in a non-interactive way."

}

pkg_config() {
	local dir
	if [ ! -d "${GRUB_ALT_INSTALLDIR}" ]; then
		einfo "Enter the directory where you want to setup grub:"
		read dir
	else
		dir="${GRUB_ALT_INSTALLDIR}"
	fi
	setup_boot_dir "${dir}"
}
