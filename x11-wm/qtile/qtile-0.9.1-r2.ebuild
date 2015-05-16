# Distributed under the terms of the GNU General Public License v2

EAPI=5-progress
PYTHON_ABI_TYPE="multiple"
PYTHON_RESTRICTED_ABIS="2.6 3.*"

inherit distutils

SRC_URI="https://github.com/qtile/qtile/archive/v${PV}.tar.gz -> ${P}.tar.gz"
KEYWORDS="~*"

DESCRIPTION="A pure-Python tiling window manager."
HOMEPAGE="http://www.qtile.org/"

LICENSE="MIT"
SLOT="0"
IUSE="dbus widget-google-calendar widget-imap widget-launchbar widget-mpd widget-mpris widget-wlan"

REQUIRED_USE="widget-mpris? ( dbus )"

RDEPEND="x11-libs/pango
	$(python_abi_depend ">=dev-python/cairocffi-0.6" )
	$(python_abi_depend ">=dev-python/cffi-0.8.2" )
	$(python_abi_depend ">=dev-python/six-1.4.1" )
	$(python_abi_depend ">=dev-python/xcffib-0.1.11" )
	$(python_abi_depend "dev-python/trollius" )
	dbus? (
		$(python_abi_depend "dev-python/dbus-python" )
		$(python_abi_depend ">=dev-python/pygobject-3.4.2-r1000" )
	)
	widget-google-calendar? (
		$(python_abi_depend "dev-python/httplib2" )
		$(python_abi_depend "dev-python/python-dateutil" )
		$(python_abi_depend "dev-python/google-api-python-client" )
		$(python_abi_depend "dev-python/oauth2client" )
	)
	widget-imap? ($(python_abi_depend "dev-python/keyring" ))
	widget-launchbar? ($(python_abi_depend "dev-python/pyxdg" ))
	widget-mpd? ($(python_abi_depend "dev-python/python-mpd" ))
	widget-wlan? ($(python_abi_depend "net-wireless/python-wifi" ))
"
DEPEND="${RDEPEND}
	$(python_abi_depend "dev-python/setuptools" )
"
DOCS=( CHANGELOG README.rst )

python_install_all() {
	distutils-r1_python_install_all

	insinto /usr/share/xsessions
	doins resources/qtile.desktop

	exeinto /etc/X11/Sessions
	newexe "${FILESDIR}"/${PN}-session ${PN}
}
