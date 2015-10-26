# Distributed under the terms of the GNU General Public License v2

# emacs support disabled due to #99533 #335900

EAPI="4"

inherit eutils systemd toolchain-funcs autotools multilib-minimal

DESCRIPTION="Console-based mouse driver"
HOMEPAGE="http://www.nico.schottelius.org/software/gpm/"
SRC_URI="http://www.nico.schottelius.org/software/${PN}/archives/${P}.tar.lzma"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"
IUSE="selinux static-libs"

RDEPEND="selinux? ( sec-policy/selinux-gpm )
	abi_x86_32? (
		!<=app-emulation/emul-linux-x86-baselibs-20130224-r12
		!app-emulation/emul-linux-x86-baselibs[-abi_x86_32(-)]
	)"
DEPEND="app-arch/xz-utils
	sys-apps/texinfo
	virtual/yacc"

src_prepare() {
	# fix ABI values
	sed -i \
		-e '/^abi_lev=/s:=.*:=1:' \
		-e '/^abi_age=/s:=.*:=20:' \
		configure.ac.footer || die
	sed -i -e '/ACLOCAL/,$d' autogen.sh || die
	./autogen.sh
	eautoreconf
	multilib_copy_sources
}

multilib_src_configure() {
	econf \
		--without-curses \
		--sysconfdir=/etc/gpm \
		$(use_enable static-libs static) \
		emacs=/bin/false
}

multilib_src_compile() {
	# make sure nothing compiled is left
	emake clean
	emake EMACS=: $(multilib_is_native_abi || echo "PROG= ")
}

multilib_src_install() {
	emake \
		DESTDIR="${D}" \
		EMACS=: ELISP="" \
		$(multilib_is_native_abi || echo "PROG= ") \
		install

	dosym libgpm.so.1 /usr/$(get_libdir)/libgpm.so
	multilib_is_native_abi && gen_usr_ldscript -a gpm
}

multilib_src_install_all() {
	insinto /etc/gpm
	doins conf/gpm-*.conf

	dodoc README TODO
	dodoc doc/Announce doc/FAQ doc/README*

	newinitd "${FILESDIR}"/gpm.rc6-2 gpm
	newconfd "${FILESDIR}"/gpm.conf.d gpm
	systemd_dounit "${FILESDIR}"/gpm.service
}
