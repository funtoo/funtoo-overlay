# Distributed under the terms of the GNU General Public License v2

EAPI=2

DESCRIPTION="manage ssh and GPG keys in a convenient and secure manner. Frontend for ssh-agent/ssh-add"
HOMEPAGE="http://www.funtoo.org/Package:Keychain"
SRC_URI="mirror://funtoo/distfiles/keychain/${P}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="alpha amd64 arm hppa ia64 ~mips ppc ppc64 s390 sh sparc x86 ~ppc-aix ~sparc-fbsd ~x86-fbsd ~x86-freebsd ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE=""

DEPEND=""
RDEPEND="app-shells/bash || ( net-misc/openssh net-misc/ssh )"

src_compile() {
	echo
}

src_install() {
	dobin keychain || die "dobin failed"
	doman keychain.1 || die "doman failed"
	dodoc ChangeLog README.rst || die
}

pkg_postinst() {
	einfo "Please see the keychain man page or visit"
	einfo "$HOMEPAGE"
	einfo "for information on how to use keychain."
}
