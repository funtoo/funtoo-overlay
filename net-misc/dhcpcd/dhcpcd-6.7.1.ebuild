# Distributed under the terms of the GNU General Public License v2

EAPI="5"

MY_P="${P/_alpha/-alpha}"
MY_P="${MY_P/_beta/-beta}"
MY_P="${MY_P/_rc/-rc}"
SRC_URI="http://roy.marples.name/downloads/${PN}/${MY_P}.tar.bz2"
KEYWORDS="*"
S="${WORKDIR}/${MY_P}"

inherit eutils

DESCRIPTION="A fully featured, yet light weight RFC2131 compliant DHCP client"
HOMEPAGE="http://roy.marples.name/projects/dhcpcd/"
LICENSE="BSD-2"
SLOT="0"
IUSE="elibc_glibc +embedded ipv6 kernel_linux +udev +zeroconf"

COMMON_DEPEND="udev? ( virtual/udev )"
DEPEND="${COMMON_DEPEND}"
RDEPEND="${COMMON_DEPEND}"

src_prepare()
{
	if ! use zeroconf; then
			elog "Disabling zeroconf support"
			{
					echo
					echo "# dhcpcd ebuild requested no zeroconf"
					echo "noipv4ll"
			} >> dhcpcd.conf
	fi

	epatch_user
}

src_configure()
{
	local dev hooks rundir
	use udev || dev="--without-dev --without-udev"
	hooks="--with-hook=ntp.conf"
	use elibc_glibc && hooks="${hooks} --with-hook=yp.conf"
	use kernel_linux && rundir="--rundir=${EPREFIX}/run"
	econf \
		--prefix="${EPREFIX}" \
		--libexecdir="${EPREFIX}/lib/dhcpcd" \
		--dbdir="${EPREFIX}/var/lib/dhcpcd" \
		--localstatedir="${EPREFIX}/var" \
		${rundir} \
		$(use_enable embedded) \
		$(use_enable ipv6) \
		${dev} \
		${hooks}
}

src_install()
{
	default
	newinitd "${FILESDIR}"/${PN}.initd-r3 ${PN}
}

pkg_postinst()
{
	# Upgrade the duid file to the new format if needed
	local old_duid="${ROOT}"/var/lib/dhcpcd/dhcpcd.duid
	local new_duid="${ROOT}"/etc/dhcpcd.duid
	if [ -e "${old_duid}" ] && ! grep -q '..:..:..:..:..:..' "${old_duid}"; then
		sed -i -e 's/\(..\)/\1:/g; s/:$//g' "${old_duid}"
	fi

	# Move the duid to /etc, a more sensible location
	if [ -e "${old_duid}" -a ! -e "${new_duid}" ]; then
		cp -p "${old_duid}" "${new_duid}"
	fi

	if [ -z "$REPLACING_VERSIONS" ]; then
		if use zeroconf; then
			elog
			elog "dhcpcd has zeroconf support active by default."
			elog "This means it will always obtain an IP address even if no"
			elog "DHCP server can be contacted, which will break any existing"
			elog "failover support you may have configured in your net configuration."
			elog "This behaviour can be controlled with the noipv4ll configuration"
			elog "file option or the -L command line switch."
			elog "See the dhcpcd and dhcpcd.conf man pages for more details."
		fi

		elog
		elog "Dhcpcd has duid enabled by default, and this may cause issues"
		elog "with some dhcp servers. For more information, see"
		elog "https://bugs.gentoo.org/show_bug.cgi?id=477356"
	fi

	if ! has_version net-dns/bind-tools; then
		elog
		elog "If you activate the lookup-hostname hook to look up your hostname"
		elog "using the dns, you need to install net-dns/bind-tools."
	fi
}
