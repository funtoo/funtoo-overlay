# Distributed under the terms of the GNU General Public License v2

EAPI="5"

inherit base bash-completion-r1 eutils toolchain-funcs udev

DESCRIPTION="OpenVZ Containers control utility"
HOMEPAGE="http://openvz.org/"
SRC_URI="http://download.openvz.org/utils/${PN}/${PV}/src/${P}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="x86 amd64"
IUSE="+ploop +vzmigrate"

RDEPEND="net-firewall/iptables
		sys-apps/ed
		>=sys-apps/iproute2-3.3.0
		>=sys-fs/vzquota-3.1
		ploop? (
			>=sys-cluster/ploop-1.13
			sys-block/parted
			sys-fs/quota
			dev-libs/libxml2
			)
		>=dev-libs/libcgroup-0.38
		vzmigrate? (
		net-misc/openssh
		net-misc/rsync[xattr,acl]
		app-arch/tar[xattr,acl]
		net-misc/bridge-utils
		virtual/awk
			)
		virtual/udev
		app-arch/xz-utils
		app-misc/vzstats
		"

DEPEND="${RDEPEND}
	virtual/pkgconfig
	"

src_prepare() {
	# Set default OSTEMPLATE on gentoo
	sed -i -e 's:=redhat-:=funtoo-:' etc/dists/default || die 'sed on etc/dists/default failed'
	# Set proper udev directory
	sed -i -e "s:/lib/udev:$(get_udevdir):" src/lib/dev.c || die 'sed on src/lib/dev.c failed'
	epatch "${FILESDIR}"/${PN}-4.8-vz.conf.patch
}

src_configure() {
	econf \
		--localstatedir=/var \
		--enable-udev \
		--enable-bashcomp \
		--enable-logrotate \
		--with-vz \
		$(use_with ploop) \
		--with-cgroup
}

src_install() {
	emake DESTDIR="${D}" udevdir="$(get_udevdir)"/rules.d install install-gentoo

	# install the bash-completion script into the right location
	rm -rf "${ED}"/etc/bash_completion.d
	newbashcomp etc/bash_completion.d/vzctl.sh ${PN}

	# We need to keep some dirs
	keepdir /vz/{dump,lock,root,private,template/cache}
	keepdir /etc/vz/names /var/lib/vzctl/veip

	# enable bridge auto-add for veth devices:
	insinto /etc/vz
	doins ${FILESDIR}/vznet.conf
	#FL-1540. Restore ve-unlimited.conf-sample file
	insinto /etc/vz/conf
	doins ${FILESDIR}/ve-unlimited.conf-sample

	newinitd ${FILESDIR}/${PVR}/vz.initd vz
}

# TODO - when Funtoo has an OpenRC with "condrestart", add an 
# /etc/init.d/vzeventd condrestart when ROOT = "/" to ensure that the
# latest vzeventd is running. Not doing this can result in containers
# not rebooting correctly after upgrade or other issues.
