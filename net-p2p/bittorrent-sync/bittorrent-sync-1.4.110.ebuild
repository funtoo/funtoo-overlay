# Distributed under the terms of the GNU General Public License v2

EAPI=5

inherit user systemd

NAME="btsync"
DESCRIPTION="Fast, unlimited and secure file-syncing. Free from the cloud."
HOMEPAGE="http://labs.bittorrent.com/experiments/sync.html"
SRC_URI="
	amd64?	( http://syncapp.bittorrent.com/${PV}/btsync_x64-${PV}.tar.gz )
	x86? ( http://syncapp.bittorrent.com/${PV}/btsync_i386-${PV}.tar.gz )"

RESTRICT="mirror strip"
LICENSE="BitTorrent"
SLOT="0"
KEYWORDS="~amd64 ~x86"

QA_PREBUILT="opt/btsync/btsync"

S="${WORKDIR}"

src_install() {
	# Install the executable
	exeinto "/opt/${NAME}"
	doexe "${S}/${NAME}"

	# Install a default configuration file
	insinto "/etc/${NAME}"
	doins "${FILESDIR}/config"

	# Install the OpenRC init file
	doinitd "${FILESDIR}/init.d/${NAME}"

	# Install the systemd unit file
	systemd_dounit "${FILESDIR}/systemd/${NAME}.service"
}

pkg_postinst() {
	local syncuser="btsync"
	local syncdir="/home/${syncuser}"

	# Let's set up the user and group for this daemon so that members of the group
	# can have write permissions.
	enewgroup "${syncuser}"
	enewuser "${syncuser}" -1 /bin/bash "${syncdir}" "${syncuser}"

	if [[ ! -d "${syncdir}" ]]; then
		# Create the .sync directory where sync metadata will be stored
		mkdir "${syncdir}/.sync"

		# Fixed home directory group permissions since it's currently btsync:root
		chown ${syncuser}:${syncuser} "${syncdir}"

		# Fix .sync directory ownership
		chown ${syncuser}:${syncuser} "${syncdir}/.sync"
	fi

	elog "In order for shared files between local users to be as easy as possible,"
	elog "please set up ACLs on your system."
	elog ""
	elog "You will also need to configure btsync by editing /etc/btsync/config"
	elog ""
	elog "After checking your config, start the service and point your browser to"
	elog "http://localhost:8888 , the default username and password is admin/admin."
}
