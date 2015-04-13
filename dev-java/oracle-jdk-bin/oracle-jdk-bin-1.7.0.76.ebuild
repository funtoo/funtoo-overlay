# Distributed under the terms of the GNU General Public License v2

EAPI="5"

inherit eutils java-vm-2 prefix versionator

JDK_URI="http://www.oracle.com/technetwork/java/javase/downloads/jdk7-downloads-1880260.html"
JCE_URI="http://www.oracle.com/technetwork/java/javase/downloads/jce-7-download-432124.html"

FX_VERSION="2_2_72"

MY_PV="$(get_version_component_range 2)u$(get_version_component_range 4)"
S_PV="$(replace_version_separator 3 '_')"

AT_x86="jdk-${MY_PV}-linux-i586.tar.gz"
AT_amd64="jdk-${MY_PV}-linux-x64.tar.gz"
#AT_arm_hflt="jdk-${MY_PV}-linux-arm-vfp-hflt.tar.gz"
AT_arm_hflt="jdk-7u60-linux-arm-vfp-hflt.tar.gz"
#AT_arm_sflt="jdk-${MY_PV}-linux-arm-vfp-sflt.tar.gz"
AT_arm_sflt="jdk-7u60-linux-arm-vfp-sflt.tar.gz"

FXDEMOS_linux="javafx_samples-${FX_VERSION}-linux.zip"

#DEMOS_x86="jdk-${MY_PV}-linux-i586-demos.tar.gz"
#DEMOS_amd64="jdk-${MY_PV}-linux-x64-demos.tar.gz"
#DEMOS_arm_hflt="jdk-${MY_PV}-linux-arm-vfp-hflt-demos.tar.gz"
#DEMOS_arm_hflt="jdk-7u60-linux-arm-vfp-hflt-demos.tar.gz"
#DEMOS_arm_sflt="jdk-${MY_PV}-linux-arm-vfp-sflt-demos.tar.gz"
DEMOS_arm_sflt="jdk-7u60-linux-arm-vfp-sflt-demos.tar.gz"

JCE_DIR="UnlimitedJCEPolicy"
JCE_FILE="${JCE_DIR}JDK7.zip"

DESCRIPTION="Oracle's Java SE Development Kit"
HOMEPAGE="http://www.oracle.com/technetwork/java/javase/"
MIR_URI="mirror://funtoo/distfiles/oracle-java"
SRC_URI=" 
	amd64? ( ${MIR_URI}/${AT_amd64} )
	x86? ( ${MIR_URI}/${AT_x86} )
	arm? ( ${MIR_URI}/${AT_arm_sflt} ${MIR_URI}/${AT_arm_hflt} )
	jce? ( ${MIR_URI}/${JCE_FILE} )"

LICENSE="Oracle-BCLA-JavaSE"
SLOT="1.7"
KEYWORDS="*"
IUSE="+X alsa aqua derby doc +fontconfig jce nsplugin pax_kernel selinux source"

RESTRICT="mirror strip"
QA_PREBUILT="*"

COMMON_DEP="
	selinux? ( sec-policy/selinux-java )"
RDEPEND="${COMMON_DEP}
	X? ( !aqua? (
		x11-libs/libX11
		x11-libs/libXext
		x11-libs/libXi
		x11-libs/libXrender
		x11-libs/libXtst
	) )
	alsa? ( media-libs/alsa-lib )
	doc? ( dev-java/java-sdk-docs:1.7 )
	fontconfig? ( media-libs/fontconfig )
	!prefix? ( sys-libs/glibc )"
# scanelf won't create a PaX header, so depend on paxctl to avoid fallback
# marking. #427642
DEPEND="${COMMON_DEP}
	jce? ( app-arch/unzip )
	pax_kernel? ( sys-apps/paxctl )"

S="${WORKDIR}"/jdk${S_PV}

check_tarballs_available() {
	local uri=$1; shift
	local dl= unavailable=
	for dl in "${@}"; do
		[[ ! -f "${DISTDIR}/${dl}" ]] && unavailable+=" ${dl}"
	done

	if [[ -n "${unavailable}" ]]; then
		if [[ -z ${_check_tarballs_available_once} ]]; then
			einfo
			einfo "Oracle requires you to download the needed files manually after"
			einfo "accepting their license through a javascript capable web browser."
			einfo
			_check_tarballs_available_once=1
		fi
		einfo "Download the following files:"
		for dl in ${unavailable}; do
			einfo "  ${dl}"
		done
		einfo "at '${uri}'"
		einfo "and move them to '${DISTDIR}'"
		einfo
	fi
}

src_unpack() {
	# Special case for ARM soft VS hard float.
	if use arm ; then
		if [[ ${CHOST} == *-hardfloat-* ]] ; then
			unpack jdk-${MY_PV}-linux-arm-vfp-hflt.tar.gz
		else
			unpack jdk-${MY_PV}-linux-arm-vfp-sflt.tar.gz
		fi
		use jce && unpack ${JCE_FILE}
	else
		default
	fi
}

src_prepare() {
	if use jce; then
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
	if use x86; then
		rm -vf {,jre/}lib/i386/libjavaplugin_oji.so \
			{,jre/}lib/i386/libjavaplugin_nscp*.so
		rm -vrf jre/plugin/i386
	fi
	# Without nsplugin flag, also remove the new plugin
	local arch=${ARCH};
	use x86 && arch=i386;
	if ! use nsplugin; then
		rm -vf {,jre/}lib/${arch}/libnpjp2.so \
			{,jre/}lib/${arch}/libjavaplugin_jni.so
	fi

	dodoc COPYRIGHT
	dohtml README.html

	dodir "${dest}"
	cp -pPR bin include jre lib man "${ddest}" || die

	if use derby; then
		cp -pPR db "${ddest}" || die
	fi

	if use jce; then
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

	if use nsplugin; then
		install_mozilla_plugin "${dest}"/jre/lib/${arch}/libnpjp2.so
	fi

	if use source; then
		cp -p src.zip "${ddest}" || die
	fi

	if use !arm && use !x86-macos && use !x64-macos ; then
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
	# http://docs.oracle.com/javase/7/docs/technotes/guides/intl/fontconfig.html
	rm "${ddest}"/jre/lib/fontconfig.*
	if ! use fontconfig; then
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

	# Remove empty dirs we might have copied
	find "${D}" -type d -empty -exec rmdir -v {} + || die

	if use x86-macos || use x64-macos ; then
		# fix misc install_name issues
		pushd "${ddest}"/jre/lib > /dev/null || die
		local lib needed nlib npath
		for lib in \
				libJObjC libdecora-sse libglass libjavafx-{font,iio} \
				libjfxmedia libjfxwebkit libprism-es2 ;
		do
			lib=${lib}.dylib
			einfo "Fixing self-reference of ${lib}"
			install_name_tool \
				-id "${EPREFIX}${dest}/jre/lib/${lib}" \
				"${lib}"
		done
		popd > /dev/null
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
