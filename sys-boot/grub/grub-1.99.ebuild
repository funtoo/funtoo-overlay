# Distributed under the terms of the GNU General Public License v2

EAPI=3

inherit autotools flag-o-matic toolchain-funcs

BINFONT="unifont-1.0.pf2"
SRC_URI="ftp://ftp.gnu.org/gnu/${PN}/${P}.tar.xz binfont? ( mirror://funtoo/distfiles/grub/${BINFONT}.xz )"

DESCRIPTION="GNU GRUB 2 boot loader"
HOMEPAGE="http://www.gnu.org/software/grub/"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="custom-cflags debug static mkfont +binfont"

DEPEND=">=sys-libs/ncurses-5.2-r5 dev-libs/lzo mkfont? ( >=media-libs/freetype-2 media-fonts/unifont )"
RDEPEND="${RDEPEND}"
PDEPEND="sys-boot/boot-update"
PROVIDE="virtual/bootloader"

export STRIP_MASK="*/grub/*/*.mod"
QA_EXECSTACK="sbin/grub-probe sbin/grub-setup sbin/grub-mkdevicemap bin/grub-script-check bin/grub-fstest"

src_unpack() {
	cd ${WORKDIR}; unpack ${A}
	cd ${S}
}

src_prepare() {
	# without this, if mkfont is disabled in USE but unifont is merged, the
	# build will fail:
	if ! use mkfont; then
		sed -ie 's/^FONT_SOURCE =.*$/FONT_SOURCE =/g' Makefile.in || die "Makefile.in tweak"
	fi
}
src_configure() {
	econf \
		--disable-werror \
		--sbindir=/sbin \
		--bindir=/bin \
		--libdir=/$(get_libdir) \
		--disable-efiemu \
		$(use_enable mkfont grub-mkfont ) \
		$(use_enable debug mm-debug) \
		$(use_enable debug grub-emu-usb) \
		$(use_enable debug grub-fstest)
}

src_compile() {
	use custom-cflags || unset CFLAGS CPPFLAGS LDFLAGS
	use static && append-ldflags -static
	emake || die "making regular stuff"
}

src_install() {
	emake DESTDIR="${D}" install || die
	for delme in /etc /sbin/grub-update /sbin/grub-mkconfig
	do
		rm -rf ${D}/$delme || die "couldn't remove upstream stuff"
	done
	dodoc AUTHORS ChangeLog NEWS README THANKS TODO

	if use binfont
	then
		insinto /usr/share/grub/fonts
		cd ${T}; xz -dc ${DISTDIR}/${BINFONT}.xz > unifont.pf2 || die
		doins unifont.pf2 || die
	fi
}
