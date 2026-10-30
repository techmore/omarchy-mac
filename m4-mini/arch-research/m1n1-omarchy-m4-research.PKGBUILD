# Research-only private stage 2 and U-Boot. Never changes an ESP or stage 1.
pkgname=m1n1-omarchy-m4-research
pkgver=1.6.1.r1
pkgrel=1
pkgdesc='Unqualified private M4 mini bootloader research files; do not install on a real system'
arch=('aarch64')
url='https://github.com/techmore/bootloader'
license=('MIT' 'GPL-2.0-only')
options=('!strip' '!debug')
source=('m1n1-stage2.bin' 'u-boot-nodtb.bin')
sha256sums=('64fb396792a8b834242e7a5087b94604fa03ab014ce483e9bfd89ef57c67b415'
            '651351db19fcd373fc465a9796e9e9fbf9c09c46946f24c422c8d5027527e00a')

package() {
  install -Dm644 "$srcdir/m1n1-stage2.bin" "$pkgdir/usr/lib/asahi-boot/omarchy-m4-research/m1n1.bin"
  install -Dm644 "$srcdir/u-boot-nodtb.bin" "$pkgdir/usr/lib/asahi-boot/omarchy-m4-research/u-boot-nodtb.bin"
}
