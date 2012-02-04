# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-misc/dhcpcd/dhcpcd-5.2.12-r1.ebuild,v 1.6 2012/01/03 21:13:45 swift Exp $

EAPI=4

inherit eutils systemd

MY_P="${P/_alpha/-alpha}"
MY_P="${MY_P/_beta/-beta}"
MY_P="${MY_P/_rc/-rc}"
S="${WORKDIR}/${MY_P}"

DESCRIPTION="A fully featured, yet light weight RFC2131 compliant DHCP client"
HOMEPAGE="http://roy.marples.name/projects/dhcpcd/"
SRC_URI="http://roy.marples.name/downloads/${PN}/${MY_P}.tar.bz2"
LICENSE="BSD-2"

KEYWORDS="~*"

SLOT="0"
IUSE="+zeroconf elibc_glibc"

DEPEND=""
RDEPEND="!<sys-apps/openrc-0.6.0"

pkg_setup() {
	unset PREFIX #358167
}

src_prepare() {
	if ! use zeroconf; then
		elog "Disabling zeroconf support"
		{
			echo
			echo "# dhcpcd ebuild requested no zeroconf"
			echo "noipv4ll"
		} >> dhcpcd.conf
	fi
}

src_configure() {
	local hooks="--with-hook=ntp.conf"
	use elibc_glibc && hooks="${hooks} --with-hook=yp.conf"
	econf \
			--prefix="${EPREFIX}" \
			--libexecdir="${EPREFIX}/lib/dhcpcd" \
			--dbdir="${EPREFIX}/var/lib/dhcpcd" \
		--localstatedir="${EPREFIX}/var" \
		${hooks}
}

src_compile() {
	emake
}

src_install() {
	emake DESTDIR="${D}" install
	dodoc README
	newinitd "${FILESDIR}"/${PN}.initd-r3 ${PN}
	systemd_dounit "${FILESDIR}"/${PN}.service || die
}

pkg_postinst() {
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

	if use zeroconf; then
		elog "You have installed dhcpcd with zeroconf support."
		elog "This means that it will always obtain an IP address even if no"
		elog "DHCP server can be contacted, which will break any existing"
		elog "failover support you may have configured in your net configuration."
		elog "This behaviour can be controlled with the -L flag."
		elog "See the dhcpcd man page for more details."
	fi

	# Mea culpa, feel free to remove that after some time --mgorny.
	if [[ -e "${ROOT}"/etc/systemd/system/network.target.wants/${PN}.service ]]
	then
		ebegin "Moving ${PN}.service to multi-user.target"
		mv "${ROOT}"/etc/systemd/system/network.target.wants/${PN}.service \
			"${ROOT}"/etc/systemd/system/multi-user.target.wants/
		eend ${?} \
			"Please try to re-enable dhcpcd.service"
	fi
}
