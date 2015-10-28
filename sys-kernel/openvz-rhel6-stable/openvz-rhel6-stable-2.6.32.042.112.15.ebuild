# Distributed under the terms of the GNU General Public License v2

EAPI=2

inherit mount-boot check-reqs

CHECKREQS_DISK_BUILD="15G"

SLOT=$PVR
CKV=2.6.32
OKV=$CKV
OVZ_KERNEL="042stab112"
OVZ_REV="15"
OVZ_KV=${OVZ_KERNEL}.${OVZ_REV}
KV_FULL=${PN}-${PVR}
EXTRAVERSION=-${OVZ_KV}
KERNEL_ARCHIVE="linux-${CKV}.tar.bz2"
KERNEL_URI="mirror://kernel/linux/kernel/v2.6/${KERNEL_ARCHIVE}"
RESTRICT="binchecks strip mirror"

LICENSE="GPL-2"
KEYWORDS="*"
IUSE="binary"
DEPEND="binary? ( >=sys-kernel/genkernel-3.4.40.1 ) =sys-devel/gcc-4.8.5*"
DESCRIPTION="Full Linux kernel sources - RHEL6 kernel with OpenVZ patchset"
HOMEPAGE="http://www.openvz.org"
MAINPATCH="patch-${OVZ_KV}-combined.gz"
SRC_URI="${KERNEL_URI}
	http://download.openvz.org/kernel/branches/rhel6-${CKV}/${OVZ_KV}/configs/config-${CKV}-${OVZ_KV}.i686
	http://download.openvz.org/kernel/branches/rhel6-${CKV}/${OVZ_KV}/configs/config-${CKV}-${OVZ_KV}.x86_64
	http://download.openvz.org/kernel/branches/rhel6-${CKV}/${OVZ_KV}/patches/$MAINPATCH"
S="$WORKDIR/linux-${CKV}"

K_EXTRAEINFO="
This OpenVZ kernel uses RHEL6 (Red Hat Enterprise Linux 6) patch set.
This patch set is maintained by Red Hat for enterprise use, and contains
further modifications by the OpenVZ development team and the Funtoo
Linux project.

Red Hat typically only ensures that their kernels build using their
own official kernel configurations. Significant variations from these
configurations can result in build failures.

For best results, always start with a .config provided by the OpenVZ
team from:

http://wiki.openvz.org/Download/kernel/rhel6/${OVZ_KERNEL}.

On amd64 and x86 arches, one of these configurations has automatically been
enabled in the kernel source tree that was just installed for you.

Slight modifications to the kernel configuration necessary for booting
are usually fine. If you are using genkernel, the default configuration
should be sufficient for your needs."

src_unpack() {
	unpack ${KERNEL_ARCHIVE}
}

apply() {
	p=$1; shift
	case "${p##*.}" in
		gz)
			ca="gzip -dc"
			;;
		bz2)
			ca="bzip2 -dc"
			;;
		xz)
			ca="xz -dc"
			;;
		*)
			ca="cat"
			;;
	esac
	[ ! -e $p ] && die "patch $p not found"
	echo "Applying patch $p"; $ca $p | patch -s $* || die "patch $p failed"
}

pkg_setup() {
	case $ARCH in
		x86)
			defconfig_src=i686
			;;
		amd64)
			defconfig_src=x86_64
			;;
		*)
			die "unsupported ARCH: $ARCH"
			;;
	esac
	defconfig_src="${DISTDIR}/config-${CKV}-${OVZ_KV}.${defconfig_src}"
	unset ARCH; unset LDFLAGS #will interfere with Makefile if set

	if use binary ; then
		check-reqs_pkg_setup
	fi
}

src_prepare() {
	apply $DISTDIR/$MAINPATCH -p1
	apply ${FILESDIR}/rhel5-openvz-sources-2.6.18.028.064.7-bridgemac.patch -p1
	# disable video4linux version 1 - deprecated as of linux-headers-2.6.38:
	# http://forums.gentoo.org/viewtopic-t-872167.html?sid=60f2e6e08cf1f2e99b3e61772a1dc276
	sed -i -e "s:video4linux/::g" Documentation/Makefile || die
	sed -i -e "s:^\(EXTRAVERSION =\).*:\1 ${EXTRAVERSION}:" Makefile || die
	sed	-i -e 's:#export\tINSTALL_PATH:export\tINSTALL_PATH:' Makefile || die
	# perl 5.22 fix:
	sed -i -e "s:defined(@val):@val:g" kernel/timeconst.pl || die
	cp $DISTDIR/config-${CKV}-${OVZ_KV}.i686 arch/x86/configs/i386_defconfig || die
	cp $DISTDIR/config-${CKV}-${OVZ_KV}.x86_64 arch/x86/configs/x86_64_defconfig || die
	rm -f .config >/dev/null
	make -s mrproper || die "make mrproper failed"
	make -s include/linux/version.h || die "make include/linux/version.h failed"
}

src_compile() {
	! use binary && return
	install -d ${WORKDIR}/out/{lib,boot}
	install -d ${T}/{cache,twork}
	install -d $WORKDIR/build $WORKDIR/out/lib/firmware
	DEFAULT_KERNEL_SOURCE="${S}" INSTALL_FW_PATH=${WORKDIR}/out/lib/firmware CMD_KERNEL_DIR="${S}" genkernel ${GKARGS} \
		--no-save-config \
		--kernel-config="$defconfig_src" \
		--kernname="${PN}" \
		--build-src="$S" \
		--build-dst=${WORKDIR}/build \
		--kernel-cc=gcc-4.8.5 \
		--utils-cc=gcc-4.8.5 \
		--makeopts="${MAKEOPTS}" \
		--firmware-dst=${WORKDIR}/out/lib/firmware \
		--cachedir="${T}/cache" \
		--tempdir="${T}/twork" \
		--logfile="${WORKDIR}/genkernel.log" \
		--bootdir="${WORKDIR}/out/boot" \
		--lvm \
		--luks \
		--mdadm \
		--iscsi \
		--module-prefix="${WORKDIR}/out" \
		all || die "genkernel failed"
}

src_install() {
	# copy sources into place:
	dodir /usr/src
	cp -a ${S} ${D}/usr/src/linux-${PF} || die
	cd ${D}/usr/src/linux-${PF}
	# prepare for real-world use and 3rd-party module building:
	make mrproper || die
	cp $defconfig_src .config || die
	yes "" | make oldconfig || die
	# if we didn't use genkernel, we're done. The kernel source tree is left in
	# an unconfigured state - you can't compile 3rd-party modules against it yet.
	use binary || return
	make prepare || die
	make scripts || die
	# OK, now the source tree is configured to allow 3rd-party modules to be
	# built against it, since we want that to work since we have a binary kernel
	# built.
	cp -a ${WORKDIR}/out/* ${D}/ || die "couldn't copy output files into place"
	# module symlink fixup:
	rm -f ${D}/lib/modules/*/source || die
	rm -f ${D}/lib/modules/*/build || die
	cd ${D}/lib/modules
	# module strip:
	find -iname *.ko -exec strip --strip-debug {} \;
	# back to the symlink fixup:
	local moddir="$(ls -d 2*)"
	ln -s /usr/src/linux-${PF} ${D}/lib/modules/${moddir}/source || die
	ln -s /usr/src/linux-${PF} ${D}/lib/modules/${moddir}/build || die

	# Fixes FL-14
	cp "${WORKDIR}/build/System.map" "${D}/usr/src/linux-${PF}/" || die
	cp "${WORKDIR}/build/Module.symvers" "${D}/usr/src/linux-${PF}/" || die
}

pkg_postinst() {
	# if K_EXTRAEINFO is set then lets display it now
	if [[ -n ${K_EXTRAEINFO} ]]; then
		echo ${K_EXTRAEINFO} | fmt |
		while read -s ELINE; do	einfo "${ELINE}"; done
	fi
	if [ ! -e ${ROOT}usr/src/linux ]
	then
		ln -s linux-${PF} ${ROOT}usr/src/linux
	fi

	if [ -e ${ROOT}lib/modules ]; then
		depmod -a ${ROOT}lib/modules
	fi
}
