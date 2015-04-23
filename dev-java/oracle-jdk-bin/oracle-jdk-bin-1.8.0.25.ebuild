# Distributed under the terms of the GNU General Public License v2

EAPI="5"

inherit eutils java-vm-2 prefix versionator

JDK_URI="http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html"
JCE_URI="http://www.oracle.com/technetwork/java/javase/downloads/jce8-download-2133166.html"

if [[ "$(get_version_component_range 4)" == 0 ]] ; then
	S_PV="$(get_version_component_range 1-3)"
else
	MY_PV_EXT="u$(get_version_component_range 4)"
	S_PV="$(get_version_component_range 1-4)"
fi

MY_PV="$(get_version_component_range 2)${MY_PV_EXT}"

AT_amd64="jdk-${MY_PV}-linux-x64.tar.gz"
#AT_arm="jdk-${MY_PV}-linux-arm-vfp-hflt.tar.gz"
AT_arm="jdk-8u6-linux-arm-vfp-hflt.tar.gz"
AT_x86="jdk-${MY_PV}-linux-i586.tar.gz"

DEMOS_amd64="jdk-${MY_PV}-linux-x64-demos.tar.gz"
#DEMOS_arm="jdk-${MY_PV}-linux-arm-vfp-hflt-demos.tar.gz"
DEMOS_arm="jdk-8u6-linux-arm-vfp-hflt-demos.tar.gz"
DEMOS_x86="jdk-${MY_PV}-linux-i586-demos.tar.gz"

JCE_DIR="UnlimitedJCEPolicy"
JCE_FILE="${JCE_DIR}JDK8.zip"

DESCRIPTION="Oracle's Java SE Development Kit"
HOMEPAGE="http://www.oracle.com/technetwork/java/javase/"
MIR_URI="mirror://funtoo/distfiles/oracle-java"
SRC_URI=" 
	amd64? ( ${MIR_URI}/${AT_amd64} examples? ( ${MIR_URI}/${DEMOS_amd64} ) )
	arm? ( ${MIR_URI}/${AT_arm} examples? ( ${MIR_URI}/${DEMOS_arm} ) )
	x86? ( ${MIR_URI}/${AT_x86} examples? ( ${MIR_URI}/${DEMOS_x86} ) )
	jce? ( ${MIR_URI}/${JCE_FILE} )"

LICENSE="Oracle-BCLA-JavaSE examples? ( BSD )"
SLOT="1.8"
KEYWORDS="*"
IUSE="+X alsa aqua derby doc examples +fontconfig jce nsplugin pax_kernel selinux source"

RESTRICT="mirror strip"
QA_PREBUILT="*"

COMMON_DEP="
	selinux? ( sec-policy/selinux-java )"
RDEPEND="${COMMON_DEP}
	X? ( !aqua? (
		x11-libs/libX11:0
		x11-libs/libXext:0
		x11-libs/libXi:0
		x11-libs/libXrender:0
		x11-libs/libXtst:0
	) )
	alsa? ( media-libs/alsa-lib:0 )
	doc? ( dev-java/java-sdk-docs:${SLOT} )
	fontconfig? ( media-libs/fontconfig:1.0 )
	!prefix? ( sys-libs/glibc:* )"
# A PaX header isn't created by scanelf, so depend on paxctl to avoid fallback
# marking. See bug #427642.
DEPEND="${COMMON_DEP}
	jce? ( app-arch/unzip:0 )
	examples? ( kernel_linux? ( app-arch/unzip:0 ) )
	pax_kernel? ( sys-apps/paxctl:0 )"

S="${WORKDIR}/jdk"

src_unpack() {
	if use arm ; then
		# Special case for ARM soft VS hard float.
		#if [[ ${CHOST} == *-hardfloat-* ]] ; then
			unpack jdk-${MY_PV}-linux-arm-vfp-hflt.tar.gz
			use examples && unpack jdk-${MY_PV}-linux-arm-vfp-hflt-demos.tar.gz
		#else
		#	unpack jdk-${MY_PV}-linux-arm-vfp-sflt.tar.gz
		#	use examples && unpack jdk-${MY_PV}-linux-arm-vfp-sflt-demos.tar.gz
		#fi
		use jce && unpack ${JCE_FILE}
	else
		default
	fi

	# Upstream is changing their versioning scheme every release around 1.8.0.*;
	# to stop having to change it over and over again, just wildcard match and
	# live a happy life instead of trying to get this new jdk1.8.0_05 to work.
	mv "${WORKDIR}"/jdk* "${S}" || die
}

src_prepare() {
	if use jce ; then
		mv "${WORKDIR}"/${JCE_DIR} "${S}"/jre/lib/security/ || die
	fi
}

src_install() {
	local dest="/opt/${P}"
	local ddest="${ED}${dest}"

	# Create files used as storage for system preferences.
	mkdir jre/.systemPrefs || die
	touch jre/.systemPrefs/.system.lock || die
	touch jre/.systemPrefs/.systemRootModFile || die

	# We should not need the ancient plugin for Firefox 2 anymore, plus it has
	# writable executable segments
	if use x86 ; then
		rm -vf {,jre/}lib/i386/libjavaplugin_oji.so \
			{,jre/}lib/i386/libjavaplugin_nscp*.so
		rm -vrf jre/plugin/i386
	fi

	# Without nsplugin flag, also remove the new plugin
	local arch=${ARCH};
	use x86 && arch=i386;
	if ! use nsplugin ; then
		rm -vf {,jre/}lib/${arch}/libnpjp2.so \
			{,jre/}lib/${arch}/libjavaplugin_jni.so
	fi

	dodoc COPYRIGHT
	dohtml README.html

	dodir "${dest}"
	cp -pPR bin include jre lib man "${ddest}" || die

	if use derby ; then
		cp -pPR	db "${ddest}" || die
	fi

	if use examples; then
		cp -pPR demo sample "${ddest}" || die
	fi

	if use jce ; then
		dodir "${dest}"/jre/lib/security/strong-jce
		mv "${ddest}"/jre/lib/security/US_export_policy.jar \
			"${ddest}"/jre/lib/security/strong-jce || die
		mv "${ddest}"/jre/lib/security/local_policy.jar \
			"${ddest}"/jre/lib/security/strong-jce || die
		dosym "${dest}"/jre/lib/security/${JCE_DIR}/US_export_policy.jar \
			"${dest}"/jre/lib/security/US_export_policy.jar
		dosym "${dest}"/jre/lib/security/${JCE_DIR}/local_policy.jar \
			"${dest}"/jre/lib/security/local_policy.jar
	fi

	if use nsplugin ; then
		install_mozilla_plugin "${dest}"/jre/lib/${arch}/libnpjp2.so
	fi

	if use source ; then
		cp -p src.zip "${ddest}" || die
	fi

	if use !x86-macos && use !x64-macos ; then
		# Install desktop file for the Java Control Panel.
		# Using ${PN}-${SLOT} to prevent file collision with jre and or
		# other slots.  make_desktop_entry can't be used as ${P} would
		# end up in filename.
		newicon jre/lib/desktop/icons/hicolor/48x48/apps/sun-jcontrol.png \
			sun-jcontrol-${PN}-${SLOT}.png || die
		sed -e "s#Name=.*#Name=Java Control Panel for Oracle JDK ${SLOT}#" \
			-e "s#Exec=.*#Exec=/opt/${P}/jre/bin/jcontrol#" \
			-e "s#Icon=.*#Icon=sun-jcontrol-${PN}-${SLOT}#" \
			-e "s#Application;##" \
			-e "/Encoding/d" \
			jre/lib/desktop/applications/sun_java.desktop \
			> "${T}"/jcontrol-${PN}-${SLOT}.desktop || die
		domenu "${T}"/jcontrol-${PN}-${SLOT}.desktop
	fi

	# Prune all fontconfig files so libfontconfig will be used and only install
	# a Gentoo specific one if fontconfig is disabled.
	# http://docs.oracle.com/javase/8/docs/technotes/guides/intl/fontconfig.html
	rm "${ddest}"/jre/lib/fontconfig.*
	if ! use fontconfig ; then
		cp "${FILESDIR}"/fontconfig.Gentoo.properties "${T}"/fontconfig.properties || die
		eprefixify "${T}"/fontconfig.properties
		insinto "${dest}"/jre/lib/
		doins "${T}"/fontconfig.properties
	fi

	# This needs to be done before CDS - #215225
	java-vm_set-pax-markings "${ddest}"

	# see bug #207282
	einfo "Creating the Class Data Sharing archives"
	case ${ARCH} in
		arm|ia64)
			${ddest}/bin/java -client -Xshare:dump || die
			;;
		x86)
			${ddest}/bin/java -client -Xshare:dump || die
			# limit heap size for large memory on x86 #467518
			# this is a workaround and shouldn't be needed.
			${ddest}/bin/java -server -Xms64m -Xmx64m -Xshare:dump || die
			;;
		*)
			${ddest}/bin/java -server -Xshare:dump || die
			;;
	esac

	# Remove empty dirs we might have copied.
	find "${D}" -type d -empty -exec rmdir -v {} + || die

	if use x86-macos || use x64-macos ; then
		# Fix miscellaneous install_name issues.
		pushd "${ddest}"/jre/lib > /dev/null || die
		local lib needed nlib npath
		for lib in \
			decora_sse glass jfx{media,webkit} \
			javafx_{font,font_t2k,iio} prism_{common,es2,sw} \
		; do
			lib=lib${lib}.dylib
			einfo "Fixing self-reference of ${lib}"
			install_name_tool \
				-id "${EPREFIX}${dest}/jre/lib/${lib}" \
				"${lib}"
		done
		popd > /dev/null

		# TODO: This reads "jdk1{5,6}", what about "jdk1{7,8}"?
		for nlib in jdk1{5,6} ; do
			install_name_tool -change \
				/usr/lib/libgcc_s_ppc64.1.dylib \
				$($(tc-getCC) -print-file-name=libgcc_s_ppc64.1.dylib) \
				"${ddest}"/lib/visualvm/profiler/lib/deployed/${nlib}/mac/libprofilerinterface.jnilib
			install_name_tool -id \
				"${EPREFIX}${dest}"/lib/visualvm/profiler/lib/deployed/${nlib}/mac/libprofilerinterface.jnilib \
				"${ddest}"/lib/visualvm/profiler/lib/deployed/${nlib}/mac/libprofilerinterface.jnilib
		done
	fi

	set_java_env
	java-vm_revdep-mask
	java-vm_sandbox-predict /dev/random /proc/self/coredump_filter
}
