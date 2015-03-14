# Distributed under the terms of the GNU General Public License v2

EAPI="5"

inherit autotools bash-completion-r1 eutils flag-o-matic linux-info readme.gentoo systemd user versionator udev multilib-minimal

DESCRIPTION="A networked sound server with an advanced plugin system"
HOMEPAGE="http://www.pulseaudio.org"
SRC_URI="http://freedesktop.org/software/${PN}/releases/${P}.tar.xz"

# libpulse-simple and libpulse link to libpulse-core; this is daemon's
# library and can link to gdbm and other GPL-only libraries. In this
# cases, we have a fully GPL-2 package. Leaving the rest of the
# GPL-forcing USE flags for those who use them.
LICENSE="!gdbm? ( LGPL-2.1 ) gdbm? ( GPL-2 )"

SLOT="0"
KEYWORDS="*"

IUSE="+X +alsa +alsa-plugin +asyncns +caps +gdbm +glib +orc +speex +udev +webrtc-aec
	adrian-aec bluetooth dbus doc equalizer gcov gnome gtk ipv6 jack libsamplerate lirc
	native-headset neon ofono-headset oss qt4 realtime ssl systemd system-wide tcpd test xen zeroconf"

# See "*** BLUEZ support not found (requires D-Bus)" in configure.ac
REQUIRED_USE="adrian-aec? ( speex )
	bluetooth? ( dbus )
	native-headset? ( bluetooth )
	ofono-headset? ( bluetooth )
	udev? ( || ( alsa oss ) )
	webrtc-aec? ( speex )"

# alsa-utils dep is for the alsasound init.d script (see bug #155707)
# bluez dep is for the bluetooth init.d script
# PyQt4 dep is for the qpaeq script
# libpcre needed in some cases, bug #472228
# it's a valid RDEPEND, libltdl.so is used
RDEPEND=">=sys-devel/libtool-2.4.2
	|| ( elibc_glibc? ( virtual/libc )
		elibc_uclibc? ( virtual/libc )
		dev-libs/libpcre )
	>=media-libs/libsndfile-1.0.20[${MULTILIB_USEDEP}]
	X? ( >=x11-libs/libX11-1.4.0[${MULTILIB_USEDEP}]
		>=x11-libs/libxcb-1.6[${MULTILIB_USEDEP}]
		x11-libs/libSM[${MULTILIB_USEDEP}]
		x11-libs/libICE[${MULTILIB_USEDEP}]
		x11-libs/libXtst[${MULTILIB_USEDEP}] )
	alsa? ( >=media-libs/alsa-lib-1.0.19 )
	asyncns? ( net-libs/libasyncns[${MULTILIB_USEDEP}] )
	bluetooth? ( net-wireless/bluez:=
		>=sys-apps/dbus-1.0.0
		media-libs/sbc )
	caps? ( >=sys-libs/libcap-2.22-r2[${MULTILIB_USEDEP}] )
	dbus? ( >=sys-apps/dbus-1.0.0[${MULTILIB_USEDEP}] )
	dev-libs/json-c[${MULTILIB_USEDEP}]
	equalizer? ( qt4? ( dev-python/PyQt4[dbus] )
		sci-libs/fftw:3.0 )
	gdbm? ( sys-libs/gdbm )
	glib? ( >=dev-libs/glib-2.4.0[${MULTILIB_USEDEP}] )
	gnome? ( >=gnome-base/gconf-2.4.0 )
	gtk? ( x11-libs/gtk+:3 )
	jack? ( >=media-sound/jack-audio-connection-kit-0.117 )
	libsamplerate? ( >=media-libs/libsamplerate-0.1.1-r1 )
	lirc? ( app-misc/lirc )
	orc? ( >=dev-lang/orc-0.4.9 )
	realtime? ( sys-auth/rtkit )
	speex? ( >=media-libs/speex-1.2_rc1 )
	ssl? ( dev-libs/openssl )
	systemd? ( sys-apps/systemd:0=[${MULTILIB_USEDEP}] )
	system-wide? ( alsa? ( media-sound/alsa-utils )
		bluetooth? ( net-wireless/bluez:= ) )
	tcpd? ( sys-apps/tcp-wrappers[${MULTILIB_USEDEP}] )
	udev? ( >=virtual/udev-143[hwdb(+)] )
	webrtc-aec? ( media-libs/webrtc-audio-processing )
	xen? ( app-emulation/xen-tools )
	zeroconf? ( >=net-dns/avahi-0.6.12[dbus] )
	abi_x86_32? ( !<=app-emulation/emul-linux-x86-soundlibs-20131008-r1
		!app-emulation/emul-linux-x86-soundlibs[-abi_x86_32(-)] )"

DEPEND="${RDEPEND}
	dev-util/intltool
	dev-libs/libatomic_ops
	>=sys-devel/gettext-0.18.1
	sys-devel/m4
	virtual/pkgconfig
	X? ( x11-proto/xproto[${MULTILIB_USEDEP}]
		>=x11-libs/libXtst-1.0.99.2[${MULTILIB_USEDEP}] )
	doc? ( app-doc/doxygen )
	system-wide? ( || ( dev-util/unifdef sys-freebsd/freebsd-ubin ) )
	test? ( dev-libs/check )"

# This is a PDEPEND to avoid a circular dep
PDEPEND="alsa-plugin? ( >=media-plugins/alsa-plugins-1.0.27-r1[pulseaudio] )"

pkg_pretend() {
	CONFIG_CHECK="~HIGH_RES_TIMERS"
	WARNING_HIGH_RES_TIMERS="CONFIG_HIGH_RES_TIMERS:\tis not set (required for enabling timer-based scheduling in pulseaudio)\n"
	check_extra_config

	if linux_config_exists ; then
		local snd_hda_prealloc_size=$(linux_chkconfig_string SND_HDA_PREALLOC_SIZE)
		if [ -n "${snd_hda_prealloc_size}" ] && [ "${snd_hda_prealloc_size}" -lt 2048 ]; then
			ewarn "A preallocated buffer-size of 2048 (kB) or higher is recommended for the HD-audio driver!"
			ewarn "CONFIG_SND_HDA_PREALLOC_SIZE=${snd_hda_prealloc_size}"
		fi
	fi
}

pkg_setup() {
	linux-info_pkg_setup

	enewgroup audio 18 # Just make sure it exists

	if use system-wide ; then
		enewgroup pulse-access
		enewgroup pulse
		enewuser pulse -1 -1 /var/run/pulse pulse,audio
	fi
}

src_prepare() {
	# Skip test that cannot work with sandbox, bug #501846
	sed -i -e '/lock-autospawn-test/d' src/Makefile.am || die

	epatch_user
	eautoreconf
}

multilib_src_configure() {
	local myconf=()

	if use gdbm; then
		myconf+=( --with-database=gdbm )
	#elif use tdb; then
	#	myconf+=( --with-database=tdb )
	else
		myconf+=( --with-database=simple )
	fi

	if use bluetooth ; then
		if multilib_is_native_abi; then
			if has_version '<net-wireless/bluez-5'; then
				myconf+=( --disable-bluez5 --enable-bluez4 )
			else
				myconf+=( --enable-bluez5 --disable-bluez4
					$(use_enable native-headset bluez5-native-headset)
					$(use_enable ofono-headset bluez5-ofono-headset) )
			fi
 		fi

	else
		myconf+=( --disable-bluez5 --disable-bluez4 )
	fi

	myconf+=( --localstatedir="${EPREFIX}"/var
		--with-udev-rules-dir="${EPREFIX}/$(get_udevdir)"/rules.d
		--disable-coreaudio-output
		--disable-esound
		--disable-solaris
		--disable-waveout
		--enable-largefile
		$(use_enable X x11)
		$(use_enable adrian-aec)
		$(use_enable asyncns)
		$(use_enable glib glib2)
		$(use_enable oss oss-output)
		$(use_enable oss oss-wrapper)
		$(use_enable alsa)
		$(use_enable dbus)
		$(use_enable gcov)
		$(use_enable gnome gconf)
		$(use_enable gtk gtk3)
		$(use_enable jack)
		$(use_enable ipv6)
		$(use_enable libsamplerate samplerate)
		$(use_enable lirc)
		$(use_enable neon neon-opt)
		$(use_enable orc)
		$(use_enable ssl openssl)
		$(use_enable systemd systemd-daemon)
		$(use_enable systemd systemd-journal)
		$(use_enable systemd systemd-login)
		$(use_enable tcpd tcpwrap)
		$(use_enable test default-build-tests)
		$(use_enable udev)
		$(use_enable udev hal-compat)
		$(use_enable webrtc-aec)
		$(use_enable xen)
		$(use_enable zeroconf avahi)
		$(use_with caps)
		$(use_with equalizer fftw)
		$(use_with speex) )

	if ! multilib_is_native_abi ; then
		# disable all the modules and stuff
		# TODO: fill the list
		myconf+=( --disable-adrian-aec
			--disable-alsa
			--disable-avahi
			--disable-bluez4
			--disable-bluez5
			--disable-gconf
			--disable-gtk3
			--disable-jack
			--disable-lirc
			--disable-openssl
			--disable-orc
			--disable-oss-output
			--disable-samplerate
			--disable-systemd-daemon
			--disable-systemd-journal
			--disable-systemd-login
			--disable-udev
			--disable-webrtx-aec
			--disable-xen
			--without-fftw

			# tests involve random modules, so just do them for the native
			--disable-default-build-tests

			# hack around unnecessary checks
			# (results don't matter, we're not building anything using it)
			ac_cv_lib_ltdl_lt_dladvise_init=yes
			--with-database=simple
			LIBSPEEX_CFLAGS=' '
			LIBSPEEX_LIBS=' ' )
	fi

	ECONF_SOURCE=${S} \
	econf "${myconf[@]}"
}

multilib_src_compile() {
	if multilib_is_native_abi; then
		emake
	else
		local targets=( libpulse.la libpulse-simple.la )
		use glib && targets+=( libpulse-mainloop-glib.la )
		emake -C src ${targets[*]}
	fi
}

src_compile() {
	multilib-minimal_src_compile

	if use doc ; then
		pushd doxygen
		doxygen doxygen.conf
		popd
	fi
}

multilib_src_test() {
	# We avoid running the toplevel check target because that will run
	# po/'s tests too, and they are broken. Officially, it should work
	# with intltool 0.41, but that doesn't look like a stable release.
	if multilib_is_native_abi; then
		emake -C src check
	fi
}

multilib_src_install() {
	if multilib_is_native_abi; then
		emake -j1 DESTDIR="${D}" bashcompletiondir="$(get_bashcompdir)" install
	else
		local targets=( libpulse.la libpulse-simple.la )
		use glib && targets+=( libpulse-mainloop-glib.la )
		emake DESTDIR="${D}" install-pkgconfigDATA
		emake DESTDIR="${D}" -C src \
			install-libLTLIBRARIES \
			install-padsplibLTLIBRARIES \
			lib_LTLIBRARIES="${targets[*]}" \
			install-pulseincludeHEADERS
	fi
}

multilib_src_install_all() {
	# Drop the script entirely if X is disabled
	use X || rm "${ED}"/usr/bin/start-pulseaudio-x11

	if use system-wide ; then
		newconfd "${FILESDIR}/pulseaudio.conf.d" pulseaudio

		use_define() {
			local define=${2:-$(echo $1 | tr '[:lower:]' '[:upper:]')}

			use "$1" && echo "-D$define" || echo "-U$define"
		}

		unifdef $(use_define zeroconf avahi) \
			$(use_define alsa) \
			$(use_define bluetooth) \
			$(use_define udev) \
			"${FILESDIR}/pulseaudio.init.d-5" \
			> "${T}/pulseaudio"

		doinitd "${T}/pulseaudio"

		systemd_dounit "${FILESDIR}/${PN}.service"
	fi

	use zeroconf && sed -i -e '/module-zeroconf-publish/s:^#::' "${ED}/etc/pulse/default.pa"

	dodoc NEWS README todo

	if use doc ; then
		pushd doxygen/html
		dohtml *
		popd
	fi

	# Create the state directory
	use prefix || diropts -o pulse -g pulse -m0755

	# We need /var/run/pulse, bug #442852
	use system-wide && systemd_newtmpfilesd "${FILESDIR}/${PN}.tmpfiles" "${PN}.conf"

	# Prevent warnings when system-wide is not used, bug #447694
	use system-wide || rm "${ED}"/etc/dbus-1/system.d/pulseaudio-system.conf

	prune_libtool_files --all
}

pkg_postinst() {
	if use system-wide ; then
		elog "PulseAudio in Gentoo can use a system-wide pulseaudio daemon."
		elog "This support is enabled by starting the pulseaudio init.d ."
		elog "To be able to access that you need to be in the group pulse-access."
		elog "If you choose to use this feature, please make sure that you"
		elog "really want to run PulseAudio this way:"
		elog "   http://pulseaudio.org/wiki/WhatIsWrongWithSystemMode"
		elog "For more information about system-wide support, please refer to:"
		elog "	 http://pulseaudio.org/wiki/SystemWideInstance"
		if use gnome ; then
			elog
			elog "By enabling gnome USE flag, you enabled gconf support. Please note"
			elog "that you might need to remove the gnome USE flag or disable the"
			elog "gconf module on /etc/pulse/system.pa to be able to use PulseAudio"
			elog "with a system-wide instance."
		fi
	fi

	if use equalizer && ! use qt4 ; then
		elog "You've enabled the 'equalizer' USE-flag but not the 'qt4' USE-flag."
		elog "This will build the equalizer module, but the 'qpaeq' tool"
		elog "which is required to set equalizer levels will not work."
	fi

	if use native-headset && use ofono-headset ; then
		elog "You have enabled both native and ofono headset profiles. The runtime decision"
		elog "which to use is done via the 'headset' argument of module-bluetooth-discover."
	fi

	if use libsamplerate ; then
		elog "The libsamplerate based resamplers are now deprecated, because they offer no"
		elog "particular advantage over speex. Upstream suggests disabling them."
	fi

}
