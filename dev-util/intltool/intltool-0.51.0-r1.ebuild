# Distributed under the terms of the GNU General Public License v2

EAPI=5
inherit eutils

DESCRIPTION="Internationalization Tool Collection"
HOMEPAGE="https://launchpad.net/intltool/"
SRC_URI="https://launchpad.net/${PN}/trunk/${PV}/+download/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~*"
IUSE=""

DEPEND="
	>=dev-lang/perl-5.22
	dev-perl/XML-Parser
"
RDEPEND="${DEPEND}
	sys-devel/gettext
"
DOCS=( AUTHORS ChangeLog NEWS README TODO doc/I18N-HOWTO )

src_prepare() {
	# Fix handling absolute paths in single file key output, bug #470040
	# https://bugs.launchpad.net/intltool/+bug/1168941
	epatch "${FILESDIR}"/${PN}-0.50.2-absolute-paths.patch
	epatch "${FILESDIR}"/${PN}-0.51-perl5.22-regexp.patch
}
