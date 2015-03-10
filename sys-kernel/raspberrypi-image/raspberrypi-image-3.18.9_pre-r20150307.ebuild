# Distributed under the terms of the GNU General Public License v2

EAPI="5"

inherit mount-boot

GITHUB_COMMIT="2aad6d8f703f9d899b023d31d6714eea004fc61b"

DESCRIPTION="Raspberry PI binary kernel, modules, dtb and firmware"
HOMEPAGE="https://github.com/raspberrypi/firmware"
SRC_URI="https://github.com/${PN/-image//firmware}/archive/${GITHUB_COMMIT}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-2"
SLOT="${PVR}"
KEYWORDS="~arm -*"
IUSE="+rpi2 +firmware
	dtb doc rpi1 rpi1b rpi1bplus"

S="${WORKDIR}/firmware-${GITHUB_COMMIT}"

RESTRICT="binchecks mirror strip"

src_install() {
	local rpi_kv="${PV/_pre/}"

	if use rpi1 || use rpi1b || use rpi1bplus ; then
		mkdir -p ${D}/lib/modules/${rpi_kv}+
		mv -v ${S}/modules/${rpi_kv}+ ${D}/lib/modules || die
		mkdir ${D}/lib/modules/${rpi_kv}+/build
		mv -v ${S}/extra/{Module.symvers,System.map} ${D}/lib/modules/${rpi_kv}+/build || die
	fi

	if use rpi2 ; then
		mkdir -p ${D}/lib/modules/${rpi_kv}-v7+
		mv -v ${S}/modules/${rpi_kv}-v7+ ${D}/lib/modules || die
		mkdir ${D}/lib/modules/${rpi_kv}-v7+/build
		mv -v ${S}/extra/{Module7.symvers,System7.map} ${D}/lib/modules/${rpi_kv}-v7+/build || die
	fi

	if use firmware ; then
		mkdir ${D}/boot
		mv -v ${S}/boot/bootcode.bin ${D}/boot || die
		mv -v ${S}/boot/fixup{,_cd,_x}.dat ${D}/boot || die
		mv -v ${S}/boot/start{,_cd,_x}.elf ${D}/boot || die
	fi

	if use dtb ; then
		use rpi1b && mv -v ${S}/boot/bcm2708-rpi-b.dtb ${D}/boot
		use rpi1bplus && mv -v ${S}/boot/bcm2708-rpi-b-plus.dtb ${D}/boot
		use rpi2 && mv -v ${S}/boot/bcm2709-rpi-2-b.dtb ${D}/boot
		mkdir -p ${D}/boot/overlays
		mv -v ${S}/boot/overlays/*.dtb ${D}/boot/overlays || die
	fi

	if use doc ; then
		dohtml documentation/ilcomponents/*
	fi
}
