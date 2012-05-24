# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-boot/grub/grub-9999.ebuild,v 1.48 2012/01/15 02:19:54 floppym Exp $

EAPI=4

EBZR_REPO_URI="http://bzr.savannah.gnu.org/r/grub/trunk/grub/"
LIVE_ECLASS="bzr"
SRC_URI=""
DO_AUTORECONF="true"

inherit mount-boot eutils flag-o-matic pax-utils toolchain-funcs ${DO_AUTORECONF:+autotools} ${LIVE_ECLASS}
unset LIVE_ECLASS

DESCRIPTION="GNU GRUB boot loader"
HOMEPAGE="http://www.gnu.org/software/grub/"

LICENSE="GPL-3"
SLOT="0"
IUSE="custom-cflags debug device-mapper efiemu nls static sdl truetype"

GRUB_PLATFORMS=(
	# everywhere:
	emu
	# mips only:
	qemu-mips yeeloong
	# amd64, x86, ppc, ppc64:
	ieee1275
	# amd64, x86:
	coreboot multiboot efi-32 pc qemu
	# amd64:
	efi-64
)
IUSE+=" ${GRUB_PLATFORMS[@]/#/grub_platforms_}"

# os-prober: Used on runtime to detect other OSes
# xorriso (dev-libs/libisoburn): Used on runtime for mkrescue
RDEPEND="
	dev-libs/libisoburn
	dev-libs/lzo
	sys-boot/os-prober
	>=sys-libs/ncurses-5.2-r5
	debug? (
		sdl? ( media-libs/libsdl )
	)
	device-mapper? ( >=sys-fs/lvm2-2.02.45 )
	truetype? ( media-libs/freetype >=media-fonts/unifont-5 )"
DEPEND="${RDEPEND}
	>=dev-lang/python-2.5.2
	sys-devel/flex
	virtual/yacc
	sys-apps/texinfo
"
if [[ -n ${DO_AUTORECONF} ]] ; then
	DEPEND+=" >=sys-devel/autogen-5.10 sys-apps/help2man"
else
	DEPEND+=" app-arch/xz-utils"
fi

export STRIP_MASK="*/grub*/*/*.{mod,img}"
QA_EXECSTACK="
	lib64/grub2/*/setjmp.mod
	lib64/grub2/*/kernel.img
	sbin/grub2-probe
	sbin/grub2-setup
	sbin/grub2-mkdevicemap
	bin/grub2-script-check
	bin/grub2-fstest
	bin/grub2-mklayout
	bin/grub2-menulst2cfg
	bin/grub2-mkrelpath
	bin/grub2-mkpasswd-pbkdf2
	bin/grub2-mkfont
	bin/grub2-editenv
	bin/grub2-mkimage
"

QA_WX_LOAD="
	lib*/grub2/*/kernel.img
	lib*/grub2/*/setjmp.mod
"

grub_run_phase() {
	local phase=$1
	local platform=$2
	[[ -z ${phase} || -z ${platform} ]] && die "${FUNCNAME} [phase] [platform]"

	[[ -d "${WORKDIR}/build-${platform}" ]] || \
		{ mkdir "${WORKDIR}/build-${platform}" || die ; }
	pushd "${WORKDIR}/build-${platform}" > /dev/null || die

	echo ">>> Running ${phase} for platform \"${platform}\""
	echo ">>> Working in: \"${WORKDIR}/build-${platform}\""

	grub_${phase} ${platform}

	popd > /dev/null || die
}

grub_src_configure() {
	local platform=$1
	local target

	[[ -z ${platform} ]] && die "${FUNCNAME} [platform]"

	# if we have no platform then --with-platform=guessed does not work
	[[ ${platform} == "guessed" ]] && platform=""

	# check if we have to specify the target (EFI)
	# or just append correct --with-platform
	if [[ -n ${platform} ]]; then
		if [[ ${platform} == efi* ]]; then
			# EFI platform hack
			[[ ${platform/*-} == 32 ]] && target=i386
			[[ ${platform/*-} == 64 ]] && target=x86_64
			# program-prefix is required empty because otherwise it is equal to
			# target variable, which we do not want at all
			platform="
				--with-platform=${platform/-*}
				--target=${target}
				--program-prefix=
			"
		else
			platform=" --with-platform=${platform}"
		fi
	fi

	ECONF_SOURCE="${WORKDIR}/${P}/" \
	econf \
		--disable-werror \
		--sbindir=/sbin \
		--bindir=/bin \
		--libdir=/$(get_libdir) \
		--program-transform-name=s,grub,grub2, \
		$(use_enable debug mm-debug) \
		$(use_enable debug grub-emu-usb) \
		$(use_enable device-mapper) \
		$(use_enable efiemu) \
		$(use_enable nls) \
		$(use_enable truetype grub-mkfont) \
		$(use sdl && use_enable debug grub-emu-sdl) \
		${platform}
}

grub_src_compile() {
	default_src_compile
}

grub_src_install() {
	default_src_install
}

src_prepare() {
	local i j archs

	epatch_user

	# fix texinfo file name, as otherwise the grub2.info file will be
	# useless
	sed -i \
		-e '/setfilename/s:grub.info:grub2.info:' \
		-e 's:(grub):(grub2):' \
		"${S}"/docs/grub.texi
	sed -i -e '1iAM_GNU_GETTEXT_VERSION([0.18])' configure.ac

	# autogen.sh does more than just run autotools
	if [[ -n ${DO_AUTORECONF} ]] ; then
		sed -i -e '/^autoreconf/s:^:set +e; e:' autogen.sh || die
		(. ./autogen.sh) || die
	fi

	# install into the right dir for eselect #372735
	sed -i \
		-e '/^bashcompletiondir =/s:=.*:= $(datarootdir)/bash-completion:' \
		util/bash-completion.d/Makefile.in || die

	# get enabled platforms
	GRUB_ENABLED_PLATFORMS=""
	for i in ${GRUB_PLATFORMS[@]}; do
		use grub_platforms_${i} && GRUB_ENABLED_PLATFORMS+=" ${i}"
	done
	[[ -z ${GRUB_ENABLED_PLATFORMS} ]] && GRUB_ENABLED_PLATFORMS="guessed"
	elog "Going to build following platforms: ${GRUB_ENABLED_PLATFORMS}"
}

src_configure() {
	local i

	use custom-cflags || unset CFLAGS CPPFLAGS LDFLAGS
	use static && append-ldflags -static

	for i in ${GRUB_ENABLED_PLATFORMS}; do
		grub_run_phase ${FUNCNAME} ${i}
	done
}

src_compile() {
	local i

	for i in ${GRUB_ENABLED_PLATFORMS}; do
		grub_run_phase ${FUNCNAME} ${i}
	done
}

src_install() {
	local i

	for i in ${GRUB_ENABLED_PLATFORMS}; do
		grub_run_phase ${FUNCNAME} ${i}
	done

	# No need to move the info file with the live ebuild since we
	# already changed the generated file name during the preparation
	# phase.
	if [[ ${PV} != "9999" ]]; then
		# slot all collisions with grub legacy
		mv "${ED}"/usr/share/info/grub.info \
			"${ED}"/usr/share/info/grub2.info || die
	fi

	# Do pax marking
	local PAX=(
		"sbin/grub2-probe"
		"sbin/grub2-setup"
		"sbin/grub2-mkdevicemap"
		"bin/grub2-script-check"
		"bin/grub2-fstest"
		"bin/grub2-mklayout"
		"bin/grub2-menulst2cfg"
		"bin/grub2-mkrelpath"
		"bin/grub2-mkpasswd-pbkdf2"
		"bin/grub2-editenv"
		"bin/grub2-mkimage"
	)
	for e in ${PAX[@]}; do
		pax-mark -mp "${ED}/${e}"
	done

	# can't be in docs array as we use default_src_install in different builddir
	dodoc AUTHORS ChangeLog NEWS README THANKS TODO
	insinto /etc/default
	newins "${FILESDIR}"/grub.default grub
	cat <<EOF >> "${ED}"/lib*/grub2/grub-mkconfig_lib
	GRUB_DISTRIBUTOR="Gentoo"
EOF

	elog
	elog "To configure GRUB 2, check the defaults in /etc/default/grub and"
	elog "then run 'emerge --config =${CATEGORY}/${PF}'."

	# display the link to guide
	show_doc_url
}

show_doc_url() {
	elog
	elog "For informations how to configure grub-2 please refer to the guide:"
	elog "    http://dev.gentoo.org/~scarabeus/grub-2-guide.xml"
}

setup_boot_dir() {
	local dir=$1
	local use_legacy='n'

	# Make sure target directory exists
	mkdir -p "${dir}"

	if [[ -e ${dir/2/}/menu.lst ]] ; then
		# Legacy config exists, ask user what to do
		einfo "Found legacy GRUB configuration.  Do you want to convert it"
		einfo "instead of using autoconfig (y/N)?"
		read use_legacy

		use_legacy=${use_legacy,,[A-Z]}
	fi

	if [[ ${use_legacy} == y* ]] ; then
		grub1_cfg=${dir/2/}/menu.lst
		grub2_cfg=${dir}/grub.cfg

		# GRUB legacy configuration exists.  Use it instead of doing
		# our normal autoconfigure.
		#

		einfo "Converting legacy config at '${grub1_cfg}' for use by GRUB2."
		ebegin "Running: grub2-menulst2cfg '${grub1_cfg}' '${grub2_cfg}'"
		grub2-menulst2cfg "${grub1_cfg}" "${grub2_cfg}" &> /dev/null
		eend $?

		ewarn
		ewarn "Even though the conversion above succeeded, you are STRONGLY"
		ewarn "URGED to upgrade to the new GRUB2 configuration format."

		# Remind the user about the documentation
		show_doc_url
	else
		# Run GRUB 2 autoconfiguration
		einfo "Running GRUB 2 autoconfiguration."
		ebegin "grub2-mkconfig -o '${dir}/grub.cfg'"
		grub2-mkconfig -o "${dir}/grub.cfg" &> /dev/null
		eend $?
	fi

	einfo
	einfo "Remember to run grub2-install to activate GRUB2 as your default"
	einfo "bootloader."
}

pkg_config() {
	local dir
	mount-boot_mount_boot_partition
	einfo "Enter the directory where you want to setup grub2 ('${ROOT}boot/grub2/'):"
	read dir
	[[ -z ${dir} ]] && dir="${ROOT}"boot/grub2
	setup_boot_dir "${dir}"
	mount-boot_pkg_postinst
}
