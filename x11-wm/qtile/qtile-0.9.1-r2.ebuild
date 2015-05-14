# Distributed under the terms of the GNU General Public License v2

EAPI=5-progress
PYTHON_ABI_TYPE="multiple"
PYTHON_RESTRICTED_ABIS="2.6 3.*"

inherit distutils

SRC_URI="https://github.com/qtile/qtile/archive/v${PV}.tar.gz -> ${P}.tar.gz"
KEYWORDS="~*"

DESCRIPTION="A full-featured, hackable tiling window manager written and configured in Python"
HOMEPAGE="http://www.qtile.org/"

LICENSE="MIT"
SLOT="0"
IUSE="dbus widget-google-calendar widget-imap widget-launchbar widget-mpd widget-mpris widget-wlan"

REQUIRED_USE="widget-mpris? ( dbus )"

RDEPEND="x11-libs/pango
	>=dev-python/cairocffi-0.6[${PYTHON_USEDEP}]
	>=dev-python/cffi-0.8.2[${PYTHON_USEDEP}]
	>=dev-python/six-1.4.1[${PYTHON_USEDEP}]
	>=dev-python/xcffib-0.1.11[${PYTHON_USEDEP}]
	dev-python/trollius[${PYTHON_USEDEP}]
	dbus? (
		dev-python/dbus-python[${PYTHON_USEDEP}]
		>=dev-python/pygobject-3.4.2-r1000[${PYTHON_USEDEP}]
	)
	widget-google-calendar? (
		dev-python/httplib2[${PYTHON_USEDEP}]
		dev-python/python-dateutil[${PYTHON_USEDEP}]
		dev-python/google-api-python-client[${PYTHON_USEDEP}]
		dev-python/oauth2client[${PYTHON_USEDEP}]
	)
	widget-imap? ( dev-python/keyring[${PYTHON_USEDEP}] )
	widget-launchbar? ( dev-python/pyxdg[${PYTHON_USEDEP}] )
	widget-mpd? ( dev-python/python-mpd[${PYTHON_USEDEP}] )
	widget-wlan? ( net-wireless/python-wifi[${PYTHON_USEDEP}] )
"
DEPEND="${RDEPEND}
	dev-python/setuptools[${PYTHON_USEDEP}]
"
DOCS=( CHANGELOG README.rst )

DISTUTILS_SINGLE_IMPL=true

python_install_all() {
	distutils-r1_python_install_all

	insinto /usr/share/xsessions
	doins resources/qtile.desktop

	exeinto /etc/X11/Sessions
	newexe "${FILESDIR}"/${PN}-session ${PN}
}
