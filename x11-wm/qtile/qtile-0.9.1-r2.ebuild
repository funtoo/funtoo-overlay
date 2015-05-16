# Distributed under the terms of the GNU General Public License v2

EAPI=5-progress
PYTHON_ABI_TYPE="multiple"
PYTHON_RESTRICTED_ABIS="2.6 3.2 3.1 *-jython *-pypy-*"

inherit distutils

SRC_URI="https://github.com/qtile/qtile/archive/v${PV}.tar.gz -> ${P}.tar.gz"
KEYWORDS="~*"

DESCRIPTION="A pure-Python tiling window manager."
HOMEPAGE="http://www.qtile.org/"

LICENSE="MIT"
SLOT="0"
IUSE="dbus widget-google-calendar widget-imap widget-launchbar widget-mpd widget-mpris widget-wlan"

REQUIRED_USE="widget-mpris? ( dbus )
	widget-google-calendar? ( python_abis_2.7 )
	widget-wlan? ( python_abis_2.7 )
"

RDEPEND="
	python_abis_3.3? ( >=dev-python/xcffib-0.1.11[python_targets_python3_3] )
	python_abis_2.7? ( >=dev-python/xcffib-0.1.11[python_targets_python2_7] )
	python_abis_3.3? ( >=dev-python/cairocffi-0.6[python_targets_python3_3] )
	python_abis_2.7? ( >=dev-python/cairocffi-0.6[python_targets_python2_7] )
	x11-libs/pango
	python_abis_3.3? ( dev-python/asyncio[python_targets_python3_3] )
	python_abis_2.7? ( dev-python/trollius[python_targets_python2_7] )
	$(python_abi_depend ">=dev-python/six-1.4.1" )
	dbus? (
		$(python_abi_depend "dev-python/dbus-python" )
		$(python_abi_depend ">=dev-python/pygobject-3.4.2-r1000" )
	)
	widget-google-calendar? (
		$(python_abi_depend "dev-python/httplib2" )
		$(python_abi_depend "dev-python/python-dateutil" )
		python_abis_2.7? ( dev-python/google-api-python-client[python_targets_python2_7] )
		python_abis_3.3? ( dev-python/oauth2client[python_targets_python3_3] )
		python_abis_2.7? ( dev-python/oauth2client[python_targets_python2_7] )
	)
	widget-imap? (
		python_abis_3.3? ( dev-python/keyring[python_targets_python3_3] )
		python_abis_2.7? ( dev-python/keyring[python_targets_python2_7] )
	)
	widget-launchbar? ( $(python_abi_depend "dev-python/pyxdg" ) )
	widget-mpd? (
		python_abis_3.3? ( dev-python/python-mpd[python_targets_python3_3] )
		python_abis_2.7? ( dev-python/python-mpd[python_targets_python2_7] )
	)
	widget-wlan? (
		python_abis_2.7? ( net-wireless/python-wifi[python_targets_python2_7] )
	)
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
