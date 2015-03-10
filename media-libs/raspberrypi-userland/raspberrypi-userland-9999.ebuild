# Distributed under the terms of the GNU General Public License v2

EAPI="5"

inherit cmake-utils git-2

DESCRIPTION="Raspberry Pi userspace tools and libraries"
HOMEPAGE="https://github.com/raspberrypi/userland"
EGIT_REPO_URI="https://github.com/${PN/-//}.git"

KEYWORDS="~arm -*"

LICENSE="BSD"
SLOT="0"

src_prepare() {
	# FIXME: Make mmal part work with -as-needed
	epatch "${FILESDIR}/${PN}-no-as-needed-mmal.patch"

	# Debian init script should not be used on Funtoo machines
	# FIXME: Port vcfiled init script to the Funtoo
	sed -i "/DESTINATION \/etc\/init.d/,+2d" interface/vmcs_host/linux/vcfiled/CMakeLists.txt || die

	# Remove Werror flag(s)
	local find_werror_files
	find_werror_files=`find "${S}" -type f -exec grep -q 'Werror' {} \; -print`
	sed -e "s; -Werror;;" \
		-e "s;-Werror;;" \
		-i "${find_werror_files}" || die


	# Change hardcoded paths
	sed -e "s;/opt/vc;/usr;" -i "${S}/makefiles/cmake/vmcs.cmake" || die
	sed -e 's;${VIDEOCORE_BUILD_DIR}/inc;${VIDEOCORE_BUILD_DIR}/include;g' \
		-e 's;${VIDEOCORE_HEADERS_BUILD_DIR}/interface/vcos;${VIDEOCORE_HEADERS_BUILD_DIR}/vcos;' \
		-i "${S}/makefiles/cmake/global_settings.cmake" || die
}

src_configure() {
	# Toolchain file not needed, but build fails if it is not specified
	local mycmakeargs="-DCMAKE_TOOLCHAIN_FILE=/dev/null"
	cmake-utils_src_configure
}

src_install() {
	dobin ${S}/build/bin/*

	insinto "/usr/include"
	doins -r "${S}/build/include/vcos"

	cd "${S}/build/lib"
	mkdir -p "opengl/raspberrypi/plugins"

	# This libs should stay at the lib root dir:
	# libvcfiled_check.a libvchostif.a libvcilcs.a
	# libvchiq_arm.so  libvcos.so libvcsm.so

	local gl_modules="libEGL.so libGLESv2_static.a libbcm_host.so
		libdebug_sym.so libkhrn_static.a libmmal_core.so
		libmmal_util.so libvmcs_rpc_client.a libEGL_static.a
		libOpenVG.so libbrcmjpeg.so libdebug_sym_static.a
		libmmal.so libmmal_omx.so libmmal_vc_client.so libGLESv2.so
		libWFC.so libcontainers.so libkhrn_client.a
		libmmal_components.so libmmal_omxutil.so libopenmaxil.so"

	for gl_module in ${gl_modules} ; do
		mv ${gl_module} opengl/raspberrypi/
	done

	mv {reader_,writer_}*.so opengl/raspberrypi/plugins/

	touch opengl/raspberrypi/.gles-only

	insinto /usr
	doins -r "${S}/build/lib"
}
