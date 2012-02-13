# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-dns/avahi/avahi-0.6.30-r3.ebuild,v 1.2 2012/01/16 16:51:09 ssuominen Exp $

EAPI="3"

PYTHON_DEPEND="python? 2"
PYTHON_USE_WITH="gdbm"
PYTHON_USE_WITH_OPT="python"

inherit autotools eutils mono python multilib flag-o-matic

DESCRIPTION="System which facilitates service discovery on a local network"
HOMEPAGE="http://avahi.org/"
SRC_URI="http://avahi.org/download/${P}.tar.gz"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86 ~x86-fbsd ~x86-linux"
IUSE="+autoipd bookmarks +dbus doc gdbm gtk gtk3 howl-compat +introspection ipv6
kernel_linux mdnsresponder-compat mono python qt4 test +utils"

DBUS_DEPEND=">=sys-apps/dbus-0.30"
COMMON_DEPEND=">=dev-libs/libdaemon-0.14
	dev-libs/expat
	dev-libs/glib:2
	gdbm? ( sys-libs/gdbm )
	qt4? ( x11-libs/qt-core:4 )
	gtk? ( >=x11-libs/gtk+-2.14.0:2 )
	gtk3? ( x11-libs/gtk+:3 )
	dbus? (
		${DBUS_DEPEND}
		python? ( dev-python/dbus-python )
	)
	mono? (
		>=dev-lang/mono-1.1.10
		gtk? ( >=dev-dotnet/gtk-sharp-2 )
	)
	howl-compat? ( ${DBUS_DEPEND} )
	introspection? ( >=dev-libs/gobject-introspection-0.9.5 )
	mdnsresponder-compat? ( ${DBUS_DEPEND} )
	python? (
		gtk? ( >=dev-python/pygtk-2 )
	)
	bookmarks? (
		dev-python/twisted
		dev-python/twisted-web
	)
	kernel_linux? ( sys-libs/libcap )"
DEPEND="${COMMON_DEPEND}
	>=dev-util/intltool-0.40.5
	>=dev-util/pkgconfig-0.9.0
	doc? (
		app-doc/doxygen
		mono? ( >=virtual/monodoc-1.1.8 )
	)"
RDEPEND="${COMMON_DEPEND}
	howl-compat? ( !net-misc/howl )
	mdnsresponder-compat? ( !net-misc/mDNSResponder )"

pkg_setup() {
	if use python; then
		python_set_active_version 2
		python_pkg_setup
	fi

	if use python && ! use dbus && ! use gtk; then
		ewarn "For proper python support you should also enable the dbus and gtk USE flags!"
	fi

	# FIXME: Use REQUIRED_USE once python.eclass gets EAPI 4 support, bug 372255
	if use utils && ! { use gtk || use gtk3; }; then
		ewarn "To install the avahi utilities, USE='gtk utils' or USE='gtk3 utils''"
	fi
}

pkg_preinst() {
	enewgroup netdev
	enewgroup avahi
	enewuser avahi -1 -1 -1 avahi

	if use autoipd; then
		enewgroup avahi-autoipd
		enewuser avahi-autoipd -1 -1 -1 avahi-autoipd
	fi
}

src_prepare() {
	if use ipv6; then
		sed -i \
			-e s/use-ipv6=no/use-ipv6=yes/ \
			avahi-daemon/avahi-daemon.conf || die
	fi

	sed -i\
		-e "s:\\.\\./\\.\\./\\.\\./doc/avahi-docs/html/:../../../doc/${PF}/html/:" \
		doxygen_to_devhelp.xsl || die

	# Make gtk utils optional
	epatch "${FILESDIR}/${PN}-0.6.30-optional-gtk-utils.patch"

	# Fix init scripts for >=openrc-0.9.0 (bug #383641)
	epatch "${FILESDIR}/${PN}-0.6.x-openrc-0.9.x-init-scripts-fixes.patch"

	# Drop DEPRECATED flags, bug #384743
	sed -i -e 's:-D[A-Z_]*DISABLE_DEPRECATED=1::g' avahi-ui/Makefile.am || die

	# Prevent .pyc files in DESTDIR
	>py-compile

	epatch "${FILESDIR}"/${P}-automake-1.11.2.patch #397477

	eautoreconf
}

src_configure() {
	use sh && replace-flags -O? -O0

	local myconf="--disable-static"

	if use python; then
		myconf+="
			$(use_enable dbus python-dbus)
			$(use_enable gtk pygtk)
		"
	fi

	if use mono; then
		myconf+=" $(use_enable doc monodoc)"
	fi

	# these require dbus enabled
	if use mdnsresponder-compat || use howl-compat || use mono; then
		myconf+=" --enable-dbus"
	fi

	# We need to unset DISPLAY, else the configure script might have problems detecting the pygtk module
	unset DISPLAY

	econf \
		--localstatedir="${EPREFIX}/var" \
		--with-distro=gentoo \
		--disable-python-dbus \
		--disable-pygtk \
		--disable-xmltoman \
		--disable-monodoc \
		--enable-glib \
		--enable-gobject \
		$(use_enable test tests) \
		$(use_enable autoipd) \
		$(use_enable mdnsresponder-compat compat-libdns_sd) \
		$(use_enable howl-compat compat-howl) \
		$(use_enable doc doxygen-doc) \
		$(use_enable mono) \
		$(use_enable dbus) \
		$(use_enable python) \
		$(use_enable gtk) \
		$(use_enable gtk3) \
		$(use_enable introspection) \
		$(use_enable utils gtk-utils) \
		--disable-qt3 \
		$(use_enable qt4) \
		$(use_enable gdbm) \
		${myconf}
}

src_compile() {
	emake || die "emake failed"

	use doc && { emake avahi.devhelp || die ; }
}

src_install() {
	emake install DESTDIR="${D}" || die "make install failed"
	use bookmarks && use python && use dbus && use gtk || \
		rm -f "${ED}"/usr/bin/avahi-bookmarks

	use howl-compat && ln -s avahi-compat-howl.pc "${ED}"/usr/$(get_libdir)/pkgconfig/howl.pc
	use mdnsresponder-compat && ln -s avahi-compat-libdns_sd/dns_sd.h "${ED}"/usr/include/dns_sd.h

	if use autoipd; then
		insinto /$(get_libdir)/rcscripts/net
		doins "${FILESDIR}"/autoipd.sh || die

		insinto /$(get_libdir)/rc/net
		newins "${FILESDIR}"/autoipd-openrc.sh autoipd.sh || die
	fi

	dodoc docs/{AUTHORS,NEWS,README,TODO} || die

	if use doc; then
		dohtml -r doxygen/html/. || die
		insinto /usr/share/devhelp/books/avahi
		doins avahi.devhelp || die
	fi

	# /usr/bin/avahi-bookmarks is installed only with USE="bookmarks dbus gtk python".
	# /usr/bin/avahi-discover is installed only with USE="dbus gtk python".
	use dbus && use gtk && use python && python_convert_shebangs -r 2 "${ED}usr/bin"

	find "${ED}" -name '*.la' -exec rm -f {} +
}

pkg_postrm() {
	use python && python_mod_cleanup avahi $(use dbus && use gtk && echo avahi_discover)
}

pkg_postinst() {
	use python && python_mod_optimize avahi $(use dbus && use gtk && echo avahi_discover)

	if use autoipd; then
		echo
		elog "To use avahi-autoipd to configure your interfaces with IPv4LL (RFC3927)"
		elog "addresses, just set config_<interface>=( autoipd ) in /etc/conf.d/net!"
	fi

	if use dbus; then
		echo
		elog "If this is your first install of avahi please reload your dbus config"
		elog "with /etc/init.d/dbus reload before starting avahi-daemon!"
	fi
}
