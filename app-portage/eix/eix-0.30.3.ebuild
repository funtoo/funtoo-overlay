# Distributed under the terms of the GNU General Public License v2

EAPI=5

PLOCALES="de ru"
inherit bash-completion-r1 eutils l10n

DESCRIPTION="Search and query ebuilds, portage incl. local settings, ext. overlays, version changes, and more"
HOMEPAGE="http://eix.berlios.de"
RESTRICT="mirror"
SRC_URI="mirror://funtoo/distfiles/${P}.tar.xz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"
IUSE="debug +dep doc nls optimization security strong-optimization strong-security sqlite swap-remote tools"

BOTHDEPEND="sqlite? ( >=dev-db/sqlite-3 )
	nls? ( virtual/libintl )"
RDEPEND="${BOTHDEPEND}
	app-shells/push"
DEPEND="${BOTHDEPEND}
	app-arch/xz-utils
	nls? ( sys-devel/gettext )"

pkg_setup() {
	case " ${REPLACING_VERSIONS}" in
	*\ 0.[0-9].*|*\ 0.1[0-9].*|*\ 0.2[0-4].*|*\ 0.25.0*)
		local eixcache="${EROOT}/var/cache/${PN}"
		test -f "${eixcache}" && rm -f -- "${eixcache}";;
	esac
}

src_prepare() {
	sed -i -e "s'/'${EPREFIX}/'" -- "${S}"/tmpfiles.d/eix.conf
	epatch_user
	epatch "${FILESDIR}/${P}-disable-rsync.patch"
}

src_configure() {
	econf $(use_with sqlite) $(use_with doc extra-doc) \
		$(use_enable nls) $(use_enable tools separate-tools) \
		$(use_enable security) $(use_enable optimization) \
		$(use_enable strong-security) \
		$(use_enable strong-optimization) $(use_enable debug debugging) \
		$(use_enable swap-remote) \
		$(use_with prefix always-accept-keywords) \
		$(use_with dep dep-default) \
		--with-zsh-completion \
		--with-ebuild-sh-default="/usr/$(get_libdir)/portage/bin/ebuild.sh" \
		--with-portage-rootpath="${ROOTPATH}" \
		--with-eprefix-default="${EPREFIX}" \
		--docdir="${EPREFIX}/usr/share/doc/${PF}" \
		--htmldir="${EPREFIX}/usr/share/doc/${PF}/html"
}

src_install() {
	default
	dobashcomp bash/eix
	insinto "/usr/lib/tmpfiles.d"
	doins tmpfiles.d/eix.conf
}

pkg_postinst() {
	test -d "${EROOT}var/cache/${PN}" || {
		mkdir "${EROOT}var/cache/${PN}"
		use prefix || chown portage:portage "${EROOT}var/cache/${PN}"
	}
	local obs="${EROOT}var/cache/eix.previous"
	! test -f "${obs}" || ewarn "Found obsolete ${obs}, please remove it"
}

pkg_postrm() {
	[ -n "${REPLACED_BY_VERSION}" ] || rm -rf -- "${EROOT}var/cache/${PN}"
}
