# Distributed under the terms of the GNU General Public License v2

EAPI=3

inherit eutils mount-boot

SLOT=$PVR
CKV=3.2.57
KV_FULL=${PN}-${PVR}
EXTRAVERSION=-3
KERNEL_ARCHIVE="linux_${PV}.orig.tar.xz"
PATCH_ARCHIVE="linux_${PV}${EXTRAVERSION}.debian.tar.xz"
RESTRICT="binchecks strip mirror"
# based on : http://packages.ubuntu.com/maverick/linux-image-2.6.35-22-server
LICENSE="GPL-2"
KEYWORDS=""
IUSE="binary rt"
DEPEND="binary? ( >=sys-kernel/genkernel-3.4.40.7 )"
DESCRIPTION="Debian Sources (and optional binary kernel)"
HOMEPAGE="http://www.debian.org"
SRC_URI="http://build.funtoo.org/distfiles/${KERNEL_ARCHIVE} http://build.funtoo.org/distfiles/${PATCH_ARCHIVE}"
S="$WORKDIR/linux-${CKV}"

get_patch_list() {
	[[ -z "${1}" ]] && die "No patch series file specified"
	local patch_series="${1}"
	while read line ; do
		if [[ "${line:0:1}" != "#" ]] ; then
			echo "${line}"
		fi
	done < "${patch_series}"
}

pkg_setup() {
	export REAL_ARCH="$ARCH"
	unset ARCH; unset LDFLAGS #will interfere with Makefile if set
}

src_prepare() {

	cd ${S}
	for debpatch in $( get_patch_list "${WORKDIR}/debian/patches/series" ); do
		epatch -p1 "${WORKDIR}/debian/patches/${debpatch}"
	done

	if use rt ; then
		for rtpatch in $( get_patch_list "${WORKDIR}/debian/patches/series-rt" ) ; do
			epatch -p1 "${WORKDIR}/debian/patches/${rtpatch}"
		done
	fi

	# end of debian-specific stuff...

	sed -i -e "s:^\(EXTRAVERSION =\).*:\1 ${EXTRAVERSION}:" Makefile || die
	sed	-i -e 's:#export\tINSTALL_PATH:export\tINSTALL_PATH:' Makefile || die
	rm -f .config >/dev/null
	cp -a "${WORKDIR}"/debian "${T}"
	make -s mrproper || die "make mrproper failed"
	#make -s include/linux/version.h || die "make include/linux/version.h failed"
	cd ${S}
	cp -aR "${WORKDIR}"/debian "${S}"/debian

	## XFS LIBCRC kernel config fixes, FL-823
	epatch ${FILESDIR}/debian-sources-3.2.57-xfs-libcrc32c-fix.patch

	local opts
	use rt && opts="rt" || opts="standard"
	local myarch="amd64"
	[ "$REAL_ARCH" = "x86" ] && myarch="i386" && opts="$opts 686-pae"
	cp ${FILESDIR}/config-extract . || die
	chmod +x config-extract || die
	./config-extract ${myarch} ${opts} || die
	cp .config ${T}/config || die
	make -s mrproper || die "make mrproper failed"
	#make -s include/linux/version.h || die "make include/linux/version.h failed"
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
		--mdadm \
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

	# Fixes FL-14
		cp "${WORKDIR}/build/System.map" "${D}/usr/src/linux-${P}/" || die
		cp "${WORKDIR}/build/Module.symvers" "${D}/usr/src/linux-${P}/" || die

}

pkg_postinst() {
	if [ ! -e ${ROOT}usr/src/linux ]
	then
		ln -s linux-${P} ${ROOT}usr/src/linux
	fi

	if [ -e ${ROOT}lib/modules ]; then
		depmod -a ${ROOT}lib/modules
	fi
}
