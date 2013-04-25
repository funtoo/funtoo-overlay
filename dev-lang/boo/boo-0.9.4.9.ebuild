# Distributed under the terms of the GNU General Public License v2

EAPI=4

inherit multilib mono fdo-mime eutils

DESCRIPTION="A wrist friendly language for the CLI"
HOMEPAGE="http://boo.codehaus.org/"
SRC_URI="http://dist.codehaus.org/boo/distributions/${P}-src.tar.bz2"
LICENSE="BSD"

SLOT="0"
KEYWORDS="amd64 ppc x86"
IUSE=""

RDEPEND=">=dev-lang/mono-2.0
	x11-libs/gtksourceview:2.0"
DEPEND="${RDEPEND}
	x11-misc/shared-mime-info
	app-arch/unzip
	>=dev-dotnet/nant-0.86_beta1"

RESTRICT="test"

pkg_setup() {
	if /usr/bin/gacutil -l|grep Boo.Lang.Extensions &> /dev/null
	then
		eerror "$(best_version ${CATEGORY}/${PN}) has installed Boo.Lang.Extensions into the GAC."
		eerror "This is a bug, that will cause compilation of ${CATEGORY}/${PF} to fail. It has"
		eerror "been fixed in this version. For now, it requires that you uninstall"
		eerror "${CATEGORY}/${PN} before updating."
		eerror "Please run: emerge -C ${CATEGORY}/${PN} and try again."
		die "Please run: emerge -C ${CATEGORY}/${PN} and try again."
	fi

	# gacutil may generate a root-owned directory in ${T} which makes nant fail afterwards (bug #269907)
	rm -rf "${T}/.wapi"
}

src_prepare() {
	sed -i -e 's@${libdir}/boo@${libdir}/mono/boo@g' \
		extras/boo.pc.in || die
	# FIX: https://bugs.gentoo.org/show_bug.cgi?id=435684
	epatch "${FILESDIR}/${PN}-0.9.4.9-pt-fail.patch"
}

src_compile() {
	nant	-t:mono-2.0  \
		-D:install.prefix=/usr \
		-D:install.libdir=/usr/$(get_libdir) \
		set-release-configuration all|| die "Compilation failed"
}

src_install() {
	nant install	-D:install.buildroot="${D}" \
			-D:install.prefix="${D}"/usr \
			-D:install.share="${D}"/usr/share \
			-D:install.libdir="${D}"/usr/lib \
			-D:install.bindir="${D}/usr/bin" \
			-D:fakeroot.sharedmime="${D}"/usr \
			-D:fakeroot.gsv="${D}"/usr \
			|| die "install failed"
	rm -rf "${D}"/usr/share/gtksourceview-1.0 || die
	mono_multilib_comply
}

pkg_postinst() {
	fdo-mime_mime_database_update
}

pkg_postrm() {
	fdo-mime_mime_database_update
}
