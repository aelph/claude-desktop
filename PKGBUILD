# Maintainer: aelph
# Repackaged from Anthropic's official Debian package.

pkgname=claude-desktop
pkgver=2.9939.4
pkgrel=1
pkgdesc='Desktop application for Claude.ai (official build, repackaged from .deb)'
arch=('x86_64')
url='https://claude.ai'
license=('LicenseRef-Anthropic')
depends=(
  'alsa-lib'
  'at-spi2-core'
  'glib2'
  'glibc'
  'gtk3'
  'libdrm'
  'libnotify'
  'libsecret'
  'libxcb'
  'libxtst'
  'mesa'
  'nss'
  'util-linux-libs'
  'xdg-desktop-portal'
  'xdg-desktop-portal-impl'
  'xdg-utils'
)
optdepends=(
  'libayatana-appindicator: tray icon'
  'kwallet: secret storage on KDE Plasma'
  'gnome-keyring: secret storage on GNOME'
  'qemu-system-x86: Cowork virtual machine'
  'edk2-ovmf: UEFI firmware for Cowork virtual machine'
  'virtiofsd: system virtiofsd for Cowork (a bundled copy is used otherwise)'
)
options=('!strip' '!debug')
_repo='https://downloads.claude.ai/claude-desktop/apt/stable'
source_x86_64=("${pkgname}_${pkgver}_amd64.deb::${_repo}/pool/main/c/${pkgname}/${pkgname}_${pkgver}_amd64.deb")
sha256sums_x86_64=('SKIP')

prepare() {
  mkdir -p data
  bsdtar -xf data.tar.xz -C data
}

package() {
  cp -a data/usr "$pkgdir/"

  # Debian-only leftovers
  rm -rf "$pkgdir/usr/share/lintian"

  install -Dm644 "$pkgdir/usr/share/doc/$pkgname/copyright" \
    "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  rm -rf "$pkgdir/usr/share/doc/$pkgname"

  # Arch kernels allow unprivileged user namespaces, so Chromium's
  # namespace sandbox works without the SUID helper.
  chmod 0755 "$pkgdir/usr/lib/$pkgname/chrome-sandbox"

  # What the Debian postinst does at install time, done statically:
  # register the GNOME Shell search provider. The apt repository and
  # AppArmor profile parts are irrelevant on Arch and are skipped.
  local _sp="$pkgdir/usr/lib/$pkgname/resources/gnome-search-provider"
  install -Dm644 "$_sp/com.anthropic.Claude.search-provider.ini" \
    -t "$pkgdir/usr/share/gnome-shell/search-providers/"
  install -Dm644 "$_sp/com.anthropic.Claude.SearchProvider.service" \
    -t "$pkgdir/usr/share/dbus-1/services/"
}
