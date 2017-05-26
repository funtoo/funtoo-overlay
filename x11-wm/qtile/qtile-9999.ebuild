# Distributed under the terms of the GNU General Public License v2

EAPI=5-progress

PYTHON_ABI_TYPE="multiple"
PYTHON_RESTRICTED_ABIS="2.6 3.2 3.1 3.5 *-jython *-pypy-*"

inherit distutils git-2

SRC_URI=""
EGIT_REPO_URI="https://github.com/qtile/qtile.git"
KEYWORDS=""

DESCRIPTION="A pure-Python tiling window manager."
HOMEPAGE="http://www.qtile.org/"

LICENSE="MIT"
SLOT="0"
IUSE="dbus widget-google-calendar widget-imap widget-launchbar widget-mpd widget-mpris widget-wlan widget-keyboardkbdd"

REQUIRED_USE="widget-mpris? ( dbus )
	widget-keyboardkbdd? ( dbus )
	widget-google-calendar? ( python_abis_2.7 )
	widget-wlan? ( python_abis_2.7 )
"

RDEPEND="x11-libs/cairo[xcb] x11-libs/pango
	>=dev-python/xcffib-0.1.11
	>=dev-python/cairocffi-0.6
	python_abis_3.3? ( dev-python/asyncio )
	python_abis_2.7? ( dev-python/trollius[python_targets_python2_7] )
	$(python_abi_depend ">=dev-python/six-1.4.1" )
	dbus? ( $(python_abi_depend dev-python/dbus-python ">=dev-python/pygobject-3.4.2-r1000" ) )
	widget-google-calendar? (
		$(python_abi_depend dev-python/httplib2 dev-python/python-dateutil )
		dev-python/oauth2client
		dev-python/google-api-python-client
	)
	widget-imap? ( dev-python/keyring )
	widget-launchbar? ( $(python_abi_depend dev-python/pyxdg ) )
	widget-mpd? ( dev-python/python-mpd )
	widget-wlan? ( net-wireless/python-wifi )
"
DEPEND="${RDEPEND}
	$(python_abi_depend dev-python/setuptools )
"
DOCS=( CHANGELOG README.rst )

src_prepare() {
	if ! use dbus ; then
		(
			sed -i '/self.setup_python_dbus()/d' libqtile/manager.py
		)
	fi
	if ! use widget-google-calendar ; then
		(
			sed -i '/safe_import(".google_calendar", "GoogleCalendar")/d' libqtile/widget/__init__.py
			rm libqtile/widget/google_calendar.py
		)
	fi
	if ! use widget-imap ; then
		(
			sed -i '/safe_import(".imapwidget", "ImapWidget")/d' libqtile/widget/__init__.py
			rm libqtile/widget/imapwidget.py
		)
	fi
	if ! use widget-launchbar ; then
		(
			sed -i '/safe_import(".launchbar", "LaunchBar")/d' libqtile/widget/__init__.py
			rm libqtile/widget/launchbar.py
		)
	fi
	if ! use widget-mpd ; then
		(
			sed -i '/safe_import(".mpdwidget", "Mpd")/d' libqtile/widget/__init__.py
			rm libqtile/widget/mpdwidget.py
		)
	fi
	if ! use widget-wlan ; then
		(
			sed -i '/safe_import(".wlan", "Wlan")/d' libqtile/widget/__init__.py
			rm libqtile/widget/wlan.py
		)
	fi
	if ! use widget-mpris ; then
		(
			sed -i '/safe_import(".mpriswidget", "Mpris")/d' libqtile/widget/__init__.py
			sed -i '/safe_import(".mpris2widget", "Mpris2")/d' libqtile/widget/__init__.py
			rm libqtile/widget/mpriswidget.py
			rm libqtile/widget/mpris2widget.py
		)
	fi
	if ! use widget-keyboardkbdd ; then
		(
			sed -i '/safe_import(".keyboarkbdd", "KeyboardKbdd")/d' libqtile/widget/__init__.py
			rm libqtile/widget/keyboardkbdd.py
		)
	fi
}

src_install() {
	distutils_src_install

	insinto /usr/share/xsessions
	doins resources/qtile.desktop

	exeinto /etc/X11/Sessions
	newexe "${FILESDIR}"/${PN}-session ${PN}
}
