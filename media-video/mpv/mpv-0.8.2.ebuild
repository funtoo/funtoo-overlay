# Distributed under the terms of the GNU General Public License v2

EAPI=5
EGIT_REPO_URI="https://github.com/mpv-player/mpv.git"
PYTHON_COMPAT=( python{2_7,3_3,3_4} )
PYTHON_REQ_USE='threads(+)'

inherit eutils python-any-r1 waf-utils pax-utils fdo-mime gnome2-utils
[[ ${PV} == *9999* ]] && inherit git-r3

WAF_V="1.8.4"

DESCRIPTION="Free, open source, and cross-platform media player (fork of MPlayer/mplayer2)"
HOMEPAGE="http://mpv.io/"
SRC_URI="http://ftp.waf.io/pub/release/waf-${WAF_V}"
[[ ${PV} == *9999* ]] || \
SRC_URI+=" https://github.com/mpv-player/mpv/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-2+ BSD"
SLOT="0"
[[ ${PV} == *9999* ]] || \
KEYWORDS="~*"
IUSE="+alsa bluray bs2b cdio +cli doc-pdf dvb +dvd dvdnav egl +enca encode
+iconv jack -joystick jpeg ladspa lcms +libass libcaca libguess libmpv
lirc +lua luajit +mpg123 -openal +opengl oss pulseaudio pvr samba -sdl selinux
v4l vaapi vdpau vf-dlopen wayland +X xinerama +xscreensaver +xv +ytdl"

REQUIRED_USE="
	|| ( cli libmpv )
	dvdnav? ( dvd )
	egl? ( opengl X )
	enca? ( iconv )
	lcms? ( opengl )
	libguess? ( iconv )
	luajit? ( lua )
	opengl? ( || ( wayland X ) )
	pvr? ( v4l )
	vaapi? ( X )
	vdpau? ( X )
	wayland? ( opengl )
	xinerama? ( X )
	xscreensaver? ( X )
	xv? ( X )
	ytdl? ( lua )
"

RDEPEND=">=media-video/ffmpeg-2.1.4:0=[encode?,threads,vaapi?,vdpau?]
	sys-libs/zlib
	X? (
		x11-libs/libX11
		x11-libs/libXext
		>=x11-libs/libXrandr-1.2.0
		opengl? (
			virtual/opengl
			egl? ( media-libs/mesa[egl] )
		)
		lcms? ( >=media-libs/lcms-2.6:2 )
		vaapi? ( >=x11-libs/libva-0.34.0[X(+),opengl?] )
		vdpau? ( >=x11-libs/libvdpau-0.2 )
		xinerama? ( x11-libs/libXinerama )
		xscreensaver? ( x11-libs/libXScrnSaver )
		xv? ( x11-libs/libXv )
	)
	alsa? ( >=media-libs/alsa-lib-1.0.18 )
	bluray? ( >=media-libs/libbluray-0.3.0 )
	bs2b? ( media-libs/libbs2b )
	cdio? (
		dev-libs/libcdio
		dev-libs/libcdio-paranoia
	)
	dvb? ( virtual/linuxtv-dvb-headers )
	dvd? (
		>=media-libs/libdvdread-4.1.3
		dvdnav? ( >=media-libs/libdvdnav-4.2.0 )
	)
	enca? ( app-i18n/enca )
	iconv? ( virtual/libiconv )
	jack? ( media-sound/jack-audio-connection-kit )
	jpeg? ( virtual/jpeg:0 )
	ladspa? ( media-libs/ladspa-sdk )
	libass? (
		>=media-libs/libass-0.9.10:=[enca?,fontconfig]
		virtual/ttf-fonts
	)
	libcaca? ( >=media-libs/libcaca-0.99_beta18 )
	libguess? ( >=app-i18n/libguess-1.0 )
	lirc? ( app-misc/lirc )
	lua? (
		!luajit? ( >=dev-lang/lua-5.1:= )
		luajit? ( dev-lang/luajit:2 )
		ytdl? ( net-misc/youtube-dl )
	)
	mpg123? ( >=media-sound/mpg123-1.14.0 )
	openal? ( >=media-libs/openal-1.13 )
	pulseaudio? ( media-sound/pulseaudio )
	samba? ( net-fs/samba )
	sdl? ( media-libs/libsdl2[threads] )
	v4l? ( media-libs/libv4l )
	wayland? (
		>=dev-libs/wayland-1.6.0
		media-libs/mesa[egl,wayland]
		>=x11-libs/libxkbcommon-0.3.0
	)
"
DEPEND="${RDEPEND}
	${PYTHON_DEPS}
	virtual/pkgconfig
	>=dev-lang/perl-5.8
	dev-python/docutils
	doc-pdf? ( dev-python/rst2pdf )
	X? (
		x11-proto/videoproto
		xinerama? ( x11-proto/xineramaproto )
		xscreensaver? ( x11-proto/scrnsaverproto )
	)
"
RDEPEND+="
	selinux? ( sec-policy/selinux-mplayer )
"
DOCS=( Copyright README.md RELEASE_NOTES etc/example.conf etc/input.conf )

pkg_setup() {
	if use !libass; then
		ewarn
		ewarn "You've disabled the libass flag. No OSD or subtitles will be displayed."
	fi

	# TODO: convert to progress
	python-any-r1_pkg_setup
}

src_unpack() {
	if [[ ${PV} == *9999* ]]; then
		git-r3_src_unpack
	else
		default_src_unpack
	fi

	cp "${DISTDIR}"/waf-${WAF_V} "${S}"/waf || die
	chmod 0755 "${S}"/waf || die
}

src_prepare() {
	epatch_user
}

src_configure() {
	local mywafargs=(
		--confdir="${EPREFIX}"/etc/${PN}
		--docdir="${EPREFIX}"/usr/share/doc/${PF}
		$(usex cli '' '--disable-cplayer')
		$(use_enable libmpv libmpv-shared)
		--disable-libmpv-static
		--disable-build-date	# keep build reproducible
		--disable-optimize	# do not add '-O2' to CFLAGS
		--disable-debug-build	# do not add '-g' to CFLAGS
		$(use_enable doc-pdf pdf-build)
		$(use_enable vf-dlopen vf-dlopen-filters)
		$(use_enable cli zsh-comp)

		# optional features
		$(use_enable iconv)
		$(use_enable libguess)
		$(use_enable samba libsmbclient)
		$(use_enable lua)
		$(use_enable libass)
		$(use_enable libass libass-osd)
		$(use_enable encode encoding)
		$(use_enable joystick)
		$(use_enable lirc)
		$(use_enable bluray libbluray)
		$(use_enable dvd dvdread)
		$(use_enable dvdnav)
		$(use_enable cdio cdda)
		$(use_enable enca)
		$(use_enable mpg123)
		$(use_enable ladspa)
		$(use_enable bs2b libbs2b)
		$(use_enable lcms lcms2)
		--disable-vapoursynth	# vapoursynth is not packaged
		--disable-vapoursynth-lazy
		--enable-libavfilter
		--enable-libavdevice
		$(usex luajit '--lua=luajit' '')

		# audio outputs
		$(use_enable sdl sdl2)	# SDL output is fallback for platforms where nothing better is available
		--disable-sdl1
		$(use_enable oss oss-audio)
		--disable-rsound	# media-sound/rsound is in pro-audio overlay only
		$(use_enable pulseaudio pulse)
		$(use_enable jack)
		$(use_enable openal)
		$(use_enable alsa)

		# video outputs
		$(use_enable wayland)
		$(use_enable X x11)
		$(use_enable xscreensaver xss)
		$(use_enable X xext)
		$(use_enable xv)
		$(use_enable xinerama)
		$(use_enable X xrandr)
		$(usex X "$(use_enable opengl gl-x11)" '--disable-gl-x11')
		$(use_enable egl egl-x11)
		$(usex wayland "$(use_enable opengl gl-wayland)" '--disable-gl-wayland')
		$(use_enable opengl gl)
		$(use_enable vdpau)
		$(usex vdpau "$(use_enable opengl vdpau-gl-x11)" '--disable-vdpau-gl-x11')
		$(use_enable vaapi)
		$(use_enable vaapi vaapi-vpp)
		$(usex vaapi "$(use_enable opengl vaapi-glx)" '--disable-vaapi-glx')
		$(use_enable libcaca caca)
		$(use_enable jpeg)

		# hwaccels
		$(use_enable vaapi vaapi-hwaccel)
		$(use_enable vdpau vdpau-hwaccel)

		# tv features
		$(use_enable v4l tv)
		$(use_enable v4l tv-v4l2)
		$(use_enable v4l libv4l2)
		$(use_enable pvr)
		$(use_enable dvb)
		$(use_enable dvb dvbin)
	)
	waf-utils_src_configure "${mywafargs[@]}"
}

src_install() {
	waf-utils_src_install

	if use cli && use luajit; then
		pax-mark -m "${ED}"usr/bin/mpv
	fi
}

pkg_preinst() {
	gnome2_icon_savelist
}

pkg_postinst() {
	fdo-mime_desktop_database_update
	gnome2_icon_cache_update
}

pkg_postrm() {
	fdo-mime_desktop_database_update
	gnome2_icon_cache_update
}
