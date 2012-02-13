# Copyright 2011 Funtoo Technologies
# Distributed under the terms of the GNU General Public License v2

EAPI=2

inherit mount-boot

SLOT=$PVR
CKV=3.2.4
KV_FULL=${PN}-${PVR}
EXTRAVERSION=-1
KERNEL_ARCHIVE="linux-2.6_${PV}.orig.tar.gz"
RESTRICT="binchecks strip"
# based on : http://packages.ubuntu.com/maverick/linux-image-2.6.35-22-server
LICENSE="GPL-2"
KEYWORDS="*"
IUSE="openvz binary"
DEPEND="binary? ( >=sys-kernel/genkernel-3.4.12.6-r4 )"
RDEPEND="binary? ( >=sys-fs/udev-160 )"
DESCRIPTION="Debian Sources (and optional binary kernel)"
HOMEPAGE="http://www.debian.org"
MAINPATCH="linux-2.6_${PV}${EXTRAVERSION}.diff.gz"
SRC_URI="http://ftp.bg.debian.org/debian/pool/main/l/linux-2.6/${KERNEL_ARCHIVE}
	 http://ftp.bg.debian.org/debian/pool/main/l/linux-2.6/${MAINPATCH}"
S="$WORKDIR/linux-${CKV}"

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
	echo "Applying patch $p"; $ca $p | patch $* || die "patch $p failed"
}

pkg_setup() {
	unset ARCH; unset LDFLAGS #will interfere with Makefile if set
}

src_unpack() {
	cd ${WORKDIR}
	unpack ${KERNEL_ARCHIVE}
}

src_prepare() {
	cd ${WORKDIR}
	apply $DISTDIR/$MAINPATCH -p1

	# debian-specific stuff....

	mv linux-* ${S##*/} || die
	mv debian ${S##*/}/ || die
	cd ${S}
	sed -i \
		-e 's/^sys.path.append.*$/sys.path.append(".\/debian\/lib\/python")/' \
		-e 's/^_default_home =.*$/_default_home = ".\/debian\/patches"/' \
		debian/bin/patch.apply || die
	python2 debian/bin/patch.apply $KV_DEB || die
	if use openvz
	then
		python2 debian/bin/patch.apply -a $ARCH -f openvz || die
	fi

	# end of debian-specific stuff...

	sed -i -e "s:^\(EXTRAVERSION =\).*:\1 ${EXTRAVERSION}:" Makefile || die
	sed	-i -e 's:#export\tINSTALL_PATH:export\tINSTALL_PATH:' Makefile || die
	rm -f .config >/dev/null
	cp -a debian ${T} || die "couldn't back up debian dir (will be wiped by mrproper)"
	make -s mrproper || die "make mrproper failed"
	cp -a ${T}/debian . || die "couldn't restore debian directory"
	make -s include/linux/version.h || die "make include/linux/version.h failed"
	#mv "${TEMP}/configs" "${S}" || die
	cd ${S}
	local opts
	use openvz && opts="openvz"
	local myarch="amd64"
	[ "$ARCH" = "x86" ] && myarch="i386"
	cp ${FILESDIR}/config-extract . || die
	chmod +x config-extract || die
	./config-extract ${myarch} ${opts} || die
	cp .config ${T}/config || die
	make -s mrproper || die "make mrproper failed"
	make -s include/linux/version.h || die "make include/linux/version.h failed"
}

src_compile() {
	! use binary && return
	install -d ${WORKDIR}/out/{lib,boot}
	install -d ${T}/{cache,twork}
	install -d $WORKDIR/build $WORKDIR/out/lib/firmware
	genkernel \
		--no-save-config \
		--kernel-config="$T/config" \
		--kernname="${PN}" \
		--build-src="$S" \
		--build-dst=${WORKDIR}/build \
		--makeopts="${MAKEOPTS}" \
		--firmware-dst=${WORKDIR}/out/lib/firmware \
		--cachedir="${T}/cache" \
		--tempdir="${T}/twork" \
		--logfile="${WORKDIR}/genkernel.log" \
		--bootdir="${WORKDIR}/out/boot" \
		--lvm \
		--luks \
		--iscsi \
		--module-prefix="${WORKDIR}/out" \
		all || die "genkernel failed"
}

src_install() {
	# copy sources into place:
	dodir /usr/src
	cp -a ${S} ${D}/usr/src/linux-${P} || die
	cd ${D}/usr/src/linux-${P}
	# prepare for real-world use and 3rd-party module building:
	make mrproper || die
	cp ${T}/config .config || die
	cp -a ${T}/debian debian || die
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
	local moddir="$(ls -d [23]*)"
	ln -s /usr/src/linux-${P} ${D}/lib/modules/${moddir}/source || die
	ln -s /usr/src/linux-${P} ${D}/lib/modules/${moddir}/build || die
}

pkg_postinst() {
	if [ ! -e ${ROOT}usr/src/linux ]
	then
		ln -s linux-${P} ${ROOT}usr/src/linux
	fi
}
