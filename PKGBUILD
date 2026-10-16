# Maintainer: aelph
# Repackaged from Anthropic's official Debian package.

pkgname=claude-desktop
pkgver=2.42304.0
pkgrel=1
pkgdesc='Desktop application for Claude.ai (official build, repackaged from .deb)'
arch=('x86_64')
url='https://claude.ai'
license=('LicenseRef-Anthropic')
depends=(
  'alsa-lib'
  'at-spi2-core'
  'bubblewrap'
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
  'socat'
  'util-linux-libs'
  'xdg-desktop-portal'
  'xdg-desktop-portal-impl'
  'xdg-utils'
)
# bubblewrap and socat are only "Recommends:" in the deb, but the Claude Code
# sandbox on Linux cannot start without them, so they are hard dependencies.
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
sha256sums_x86_64=('74cd2ccc29d24165144e455cbc872c6cc2a24a263b83e73420e95f89166d4aa4')

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

  # Cowork hardcodes Debian paths for the VM stack. virtiofsd: the app
  # looks in /usr/libexec and /usr/bin, Arch installs it to /usr/lib.
  ln -s ../lib/virtiofsd "$pkgdir/usr/bin/virtiofsd"
  # UEFI firmware: the app opens /usr/share/OVMF/OVMF_CODE_4M.fd; on Arch
  # /usr/share/OVMF is a symlink to /usr/share/edk2 (edk2-ovmf), where the
  # firmware lives in x64/ under different names.
  install -d "$pkgdir/usr/share/edk2"
  ln -s x64/OVMF_CODE.4m.fd "$pkgdir/usr/share/edk2/OVMF_CODE_4M.fd"
  ln -s x64/OVMF_VARS.4m.fd "$pkgdir/usr/share/edk2/OVMF_VARS_4M.fd"
}
