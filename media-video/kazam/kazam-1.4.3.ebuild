# Distributed under the terms of the GNU General Public License v2

EAPI=5
PYTHON_COMPAT=( python{3_1,3_2,3_3} )

inherit distutils-r1

DESCRIPTION="A screencasting program created with design in mind"
HOMEPAGE="https://launchpad.net/kazam"
SRC_URI="http://launchpad.net/${PN}/stable/${PV}/+download/${P}.tar.gz"
S="${WORKDIR}/${P}-0ubuntu1/"

LICENSE="GPL-3 LGPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="pulseaudio"

DEPEND="dev-python/python-distutils-extra"
RDEPEND="
x11-libs/gtk+:3[introspection]
x11-libs/libwnck[introspection]
x11-libs/gdk-pixbuf
media-libs/gstreamer[introspection]
media-libs/gst-plugins-good
media-plugins/gst-plugins-x264
media-plugins/gst-plugins-ximagesrc
virtual/ffmpeg
media-libs/libtheora
media-libs/libmatroska
dev-python/gst-python
dev-python/dbus-python
dev-python/pycairo
dev-python/pyxdg
dev-python/pygobject
pulseaudio? ( media-sound/pulseaudio )
"
