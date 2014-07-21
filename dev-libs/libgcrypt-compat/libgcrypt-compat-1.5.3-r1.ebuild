# Distributed under the terms of the GNU General Public License v2

EAPI=5
AUTOTOOLS_AUTORECONF=1

inherit autotools-multilib

DESCRIPTION="General purpose crypto library based on the code used in GnuPG"
HOMEPAGE="http://www.gnupg.org/"
SRC_URI="mirror://gnupg/libgcrypt/libgcrypt-${PV}.tar.bz2
	ftp://ftp.gnupg.org/gcrypt/libgcrypt/libgcrypt-${PV}.tar.bz2"

LICENSE="LGPL-2.1 MIT"
SLOT="0/11" # subslot = soname major version
KEYWORDS="*"
IUSE="static-libs"

# We depend on libgcrypt-1.6 or higher because this ebuild is designed to sit alongside
# an existing libgcrypt install, and just provide compatibility libs for apps that require
# older libgcrypt.

RDEPEND=">=dev-libs/libgcrypt-1.6 
		!dev-libs/libgcrypt:0/11
		>=dev-libs/libgpg-error-1.12-r2[${MULTILIB_USEDEP}]
		abi_x86_32? (
	 		!<=app-emulation/emul-linux-x86-baselibs-20131008-r19
	   		!app-emulation/emul-linux-x86-baselibs[-abi_x86_32]
		)"
DEPEND="${RDEPEND}"
S="$WORKDIR/libgcrypt-${PV}"

DOCS=( AUTHORS ChangeLog NEWS README THANKS TODO )

PATCHES=(
	"${FILESDIR}"/libgcrypt-1.5.0-uscore.patch
	"${FILESDIR}"/libgcrypt-multilib-syspath.patch
)

src_configure() {
	local myeconfargs=(
		--disable-padlock-support # bug 201917
		--disable-dependency-tracking
		--enable-noexecstack
		--disable-O-flag-munging
		$(use_enable static-libs static)

		# disabled due to various applications requiring privileges
		# after libgcrypt drops them (bug #468616)
		--without-capabilities
	)
	autotools-multilib_src_configure
}

post_src_install() {
	cd ${D}
	# We are only installing the .so.x and .so.x.y libs, not the main .so symlink or anything else.
	# This will be sufficient to allow things like google-chrome to run.
	rm -rf usr/{lib,lib64,lib32}/*.so usr/bin usr/include usr/share || die
}
