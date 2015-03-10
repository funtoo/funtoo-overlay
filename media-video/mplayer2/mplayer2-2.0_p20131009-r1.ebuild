# Distributed under the terms of the GNU General Public License v2

EAPI="5"

# https://bugs.gentoo.org/show_bug.cgi?id=434356#c4
PYTHON_COMPAT=( python{2_7,3_2,3_3} )

EGIT_REPO_URI="git://git.mplayer2.org/mplayer2.git"

inherit toolchain-funcs flag-o-matic multilib eutils python-any-r1
[[ ${PV} == *9999* ]] && inherit git-2

NAMESUF="${PN/mplayer/}"
DESCRIPTION="Media Player for Linux"
HOMEPAGE="http://www.mplayer2.org/"
[[ ${PV} == *9999* ]] || \
SRC_URI="http://dev.gentoo.org/~maksbotan/${P}.tar.xz"

LICENSE="GPL-3"
SLOT="0"
[[ ${PV} == *9999* ]] || \
KEYWORDS="*"
IUSE="+alsa aqua bluray bs2b cddb +cdio cpudetection debug directfb doc dvb +dvd
+dvdnav +enca ftp gif +iconv ipv6 jack joystick jpeg ladspa lcms +libass libcaca
lirc md5sum mng +mp3 +network +opengl oss png pnm portaudio +postproc pulseaudio
pvr +quvi radio samba selinux +shm tga +threads +unicode v4l vcd vdpau +X xinerama
+xscreensaver +xv yuv4mpeg"
IUSE+=" symlink"

CPU_FEATURES="cpu_flags_x86_3dnow:3dnow cpu_flags_x86_3dnowext:3dnowext altivec +cpu_flags_x86_mmx:mmx cpu_flags_x86_mmxext:mmxext cpu_flags_x86_sse:sse cpu_flags_x86_sse2:sse2 cpu_flags_x86_ssse3:ssse3"

for x in ${CPU_FEATURES}; do
	IUSE+=" ${x%:*}"
done

REQUIRED_USE="
	cddb? ( cdio network )
	dvdnav? ( dvd )
	enca? ( iconv )
	lcms? ( opengl )
	libass? ( iconv )
	opengl? ( || ( aqua X ) )
	portaudio? ( threads )
	pvr? ( v4l )
	radio? ( v4l || ( alsa oss ) )
	v4l? ( threads )
	vdpau? ( X )
	xinerama? ( X )
	xscreensaver? ( X )
	xv? ( X )
"

RDEPEND+="
	sys-libs/ncurses
	sys-libs/zlib
	X? (
		x11-libs/libXext
		x11-libs/libXxf86vm
		opengl? ( virtual/opengl )
		lcms? ( media-libs/lcms:2 )
		vdpau? ( x11-libs/libvdpau )
		xinerama? ( x11-libs/libXinerama )
		xscreensaver? ( x11-libs/libXScrnSaver )
		xv? ( x11-libs/libXv )
	)
	alsa? ( media-libs/alsa-lib )
	bluray? ( media-libs/libbluray )
	bs2b? ( media-libs/libbs2b )
	cdio? (
		|| (
			dev-libs/libcdio-paranoia
			<dev-libs/libcdio-0.90[-minimal]
		)
	)
	directfb? ( dev-libs/DirectFB )
	dvb? ( virtual/linuxtv-dvb-headers )
	dvd? (
		>=media-libs/libdvdread-4.1.3
		dvdnav? ( >=media-libs/libdvdnav-4.1.3 )
	)
	enca? ( app-i18n/enca )
	gif? ( media-libs/giflib )
	iconv? ( virtual/libiconv )
	jack? ( media-sound/jack-audio-connection-kit )
	jpeg? ( virtual/jpeg )
	ladspa? ( media-libs/ladspa-sdk )
	libass? (
		>=media-libs/libass-0.9.10[enca?,fontconfig]
		virtual/ttf-fonts
	)
	libcaca? ( media-libs/libcaca )
	lirc? ( app-misc/lirc )
	mng? ( media-libs/libmng )
	mp3? ( media-sound/mpg123 )
	png? ( media-libs/libpng )
	pnm? ( media-libs/netpbm )
	portaudio? ( >=media-libs/portaudio-19_pre20111121 )
	postproc? (
		|| (
			media-libs/libpostproc
			media-video/ffmpeg:0
		)
	)
	pulseaudio? ( media-sound/pulseaudio )
	quvi? ( >=media-libs/libquvi-0.4.1 <media-libs/libquvi-0.9 )
	samba? ( net-fs/samba )
	selinux? ( sec-policy/selinux-mplayer )
	|| (
		>=media-video/libav-9.12:=[threads?,vdpau?]
		>=media-video/ffmpeg-1.2.6:0=[threads?,vdpau?]
	)
	symlink? ( !media-video/mplayer )
"
DEPEND="${RDEPEND}
	virtual/pkgconfig
	${PYTHON_DEPS}
	dev-python/docutils
	X? (
		x11-proto/videoproto
		x11-proto/xf86vidmodeproto
		xinerama? ( x11-proto/xineramaproto )
		xscreensaver? ( x11-proto/scrnsaverproto )
	)
	doc? (
		dev-libs/libxslt
		app-text/docbook-xml-dtd
		app-text/docbook-xsl-stylesheets
	)
"
DOCS=( AUTHORS Copyright README etc/example.conf etc/input.conf etc/codecs.conf )

pkg_setup() {
	if [[ ${PV} == *9999* ]]; then
		elog
		elog "This is a live ebuild which installs the latest from upstream's"
		elog "git repository, and is unsupported by Gentoo."
		elog "Everything but bugs in the ebuild itself will be ignored."
		elog
	fi

	if use !libass; then
		ewarn
		ewarn "You've disabled the libass flag. No OSD or subtitles will be displayed."
	fi

	if use cpudetection; then
		ewarn
		ewarn "You've enabled the cpudetection flag. This feature is"
		ewarn "included mainly for people who want to use the same"
		ewarn "binary on another system with a different CPU architecture."
		ewarn "MPlayer will already detect your CPU settings by default at"
		ewarn "buildtime; this flag is used for runtime detection."
		ewarn "You won't need this turned on if you are only building"
		ewarn "mplayer for this system. Also, if your compile fails, try"
		ewarn "disabling this use flag."
	fi

	einfo "For various format support you need to enable the support on your ffmpeg package:"
	einfo "    media-video/libav or media-video/ffmpeg"

	python-any-r1_pkg_setup
}

src_prepare() {
	epatch "${FILESDIR}/${PN}-py2compat.patch"
	epatch "${FILESDIR}/${P}_support_libav10.patch"
	epatch "${FILESDIR}"/buffer-padding.patch
	epatch_user

	# fix path to bash executable in configure scripts
	sed -i -e "1c\#!${EPREFIX}/bin/bash" \
		configure version.sh || die

	sed -e 's/ $(INSTALLSTRIP)//' \
		-e '/$(INSTALL) -d $(LIBDIR)/d' \
		-i Makefile || die

	if [[ -n ${NAMESUF} ]]; then
		sed -e "/^EXESUF/s,= \$_exesuf$,= ${NAMESUF}\$_exesuf," \
			-i configure || die
		sed -e "s/mplayer/${PN}/" \
			-i TOOLS/midentify.sh || die
	fi
}

src_configure() {
	local myconf=""
	local uses i

	# ebuild uses "use foo || --disable-foo" to forcibly disable
	# compilation in almost every situation. The reason for this is
	# because if --enable is used, it will force the build of that option,
	# regardless of whether the dependency is available or not.

	#####################
	# Optional features #
	#####################
	# rtc is useless and /dev/rtc0 is only readable for root
	myconf+=" --disable-rtc"
	# SDL output is fallback for platforms where nothing better is available
	myconf+=" --disable-sdl"
	myconf+="
		$(use_enable network networking)
		$(use_enable joystick)
	"
	uses="bluray ftp vcd"
	for i in ${uses}; do
		use ${i} || myconf+=" --disable-${i}"
	done
	use ipv6 || myconf+=" --disable-inet6"
	use quvi || myconf+=" --disable-libquvi"
	use samba || myconf+=" --disable-smb"
	use lirc || myconf+=" --disable-lirc --disable-lircc --disable-apple-ir"

	########
	# CDDA #
	########
	use cddb || myconf+=" --disable-cddb"
	use cdio || myconf+=" --disable-libcdio"

	################################
	# DVD read, navigation support #
	################################
	#
	# dvdread - accessing a DVD
	# dvdnav - navigation of menus
	#
	# use external libdvdcss, dvdread and dvdnav
	myconf+=" --disable-dvdread-internal --disable-libdvdcss-internal"
	use dvd || myconf+=" --disable-dvdread"
	use dvdnav || myconf+=" --disable-dvdnav"

	#############
	# Subtitles #
	#############
	uses="enca libass"
	for i in ${uses}; do
		use ${i} || myconf+=" --disable-${i}"
	done
	# iconv optionally can use unicode
	use iconv || myconf+=" --disable-iconv --charset=noconv"
	use iconv && use unicode && myconf+=" --charset=UTF-8"
	# obscure and not maintained feature
	myconf+=" --disable-unrarexec"

	#####################################
	# DVB / Video4Linux / Radio support #
	#####################################
	# BSD legacy TV/radio support, FreeBSD actually supports V4L2, and V4L2 supports this chip.
	myconf+=" --disable-tv-bsdbt848 --disable-radio-bsdbt848"
	use dvb || myconf+=" --disable-dvb"
	use pvr || myconf+=" --disable-pvr"
	use v4l || myconf+=" --disable-tv --disable-tv-v4l2 --disable-v4l2"
	if use radio; then
		myconf+=" --enable-radio --enable-radio-capture"
	else
		myconf+=" --disable-radio-v4l2"
	fi

	##########
	# Codecs #
	##########
	# better demuxers and decoders are provided by libav and ffmpeg
	uses="faad liba52 libdca libdv libnut libvorbis mad musepack speex theora tremor xanim xvid"
	for i in ${uses}; do
		myconf+=" --disable-${i}"
	done
	use mp3 || myconf+=" --disable-mpg123"
	uses="gif jpeg mng png pnm tga"
	for i in ${uses}; do
		use ${i} || myconf+=" --disable-${i}"
	done

	#################
	# Binary codecs #
	#################
	myconf+=" --disable-qtx --disable-real --disable-win32dll"

	################
	# Video Output #
	################
	uses="directfb md5sum yuv4mpeg"
	for i in ${uses}; do
		use ${i} || myconf+=" --disable-${i}"
	done
	use libcaca || myconf+=" --disable-caca"
	use postproc || myconf+=" --disable-libpostproc"

	################
	# Audio Output #
	################
	myconf+=" --disable-rsound" # media-sound/rsound is in pro-audio overlay only
	uses="alsa jack ladspa portaudio"
	for i in ${uses}; do
		use ${i} || myconf+=" --disable-${i}"
	done
	use bs2b || myconf+=" --disable-libbs2b"
	#use openal && myconf+=" --enable-openal" # build fails
	use oss || myconf+=" --disable-ossaudio"
	use pulseaudio || myconf+=" --disable-pulse"

	####################
	# Advanced Options #
	####################
	use threads || myconf+=" --disable-pthreads"

	# Platform specific flags, hardcoded on amd64 (see below)
	use cpudetection && myconf+=" --enable-runtime-cpudetection"
	use shm || myconf+=" --disable-shm"

	for i in ${CPU_FEATURES//+/}; do
		myconf+=" $(use_enable ${i%:*} ${i#*:})"
	done

	use debug && myconf+=" --enable-debug=3"

	if use x86 && gcc-specs-pie; then
		filter-flags -fPIC -fPIE
		append-ldflags -nopie
	fi

	###########################
	# X enabled configuration #
	###########################
	use X || myconf+=" --disable-x11"
	uses="vdpau xinerama xv"
	for i in ${uses}; do
		use ${i} || myconf+=" --disable-${i}"
	done
	use opengl || myconf+=" --disable-gl"
	use lcms || myconf+=" --disable-lcms2"
	use xscreensaver || myconf+=" --disable-xss"

	############################
	# OSX (aqua) configuration #
	############################
	use aqua && myconf+=" --enable-macosx-bundle --enable-macosx-finder"

	CFLAGS= LDFLAGS= ./configure \
		--cc="$(tc-getCC)" \
		--extra-cflags="${CFLAGS}" \
		--extra-ldflags="${LDFLAGS}" \
		--pkg-config="$(tc-getPKG_CONFIG)" \
		--prefix="${EPREFIX}"/usr \
		--bindir="${EPREFIX}"/usr/bin \
		--confdir="${EPREFIX}"/etc/${PN} \
		--mandir="${EPREFIX}"/usr/share/man \
		--localedir="${EPREFIX}"/usr/share/locale \
		${myconf} || die

	MAKEOPTS+=" V=1"
}

src_compile() {
	default
	use doc && emake -C DOCS/xml html-chunked
}

src_install() {
	default

	if use doc; then
		rm -r TOOLS/osxbundle* DOCS/tech/{Doxyfile,realcodecs} || die
		dodoc -r TOOLS DOCS/tech
		dohtml -r DOCS/HTML/*
	fi

	newbin TOOLS/midentify.sh midentify${NAMESUF}

	if [[ -n ${NAMESUF} ]]; then
		mv "${ED}/usr/share/man/man1/mplayer.1" "${ED}/usr/share/man/man1/mplayer${NAMESUF}.1" || die

		if use symlink; then
			dosym ${PN} /usr/bin/mplayer
			dosym midentify${NAMESUF} /usr/bin/midentify
		fi
	fi
}
