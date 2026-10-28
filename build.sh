#!/usr/bin/env bash
# Novaria OS - build script (Kubuntu 24.04 base -> custom ISO)
set -euo pipefail

ROOT="$PWD"
WORK="$ROOT/work"
OUT="$ROOT/out"
BASE_URL="https://cdimage.ubuntu.com/kubuntu/releases/24.04/release"

mkdir -p "$WORK" "$OUT"
cd "$WORK"

cleanup() {
  for m in run dev/pts dev sys proc; do
    umount -lf "$WORK/chroot/$m" 2>/dev/null || true
  done
}
trap cleanup EXIT

echo "==> Finding latest Kubuntu 24.04 ISO"
ISO_NAME=$(curl -fsSL "$BASE_URL/" | grep -oE 'kubuntu-24\.04(\.[0-9]+)?-desktop-amd64\.iso' | sort -uV | tail -1)
[ -n "$ISO_NAME" ] || { echo "Could not find Kubuntu ISO name"; exit 1; }
echo "Using $ISO_NAME"

echo "==> Downloading ISO"
curl -fL -o base.iso "$BASE_URL/$ISO_NAME"

echo "==> Verifying checksum"
curl -fsSL -o SHA256SUMS "$BASE_URL/SHA256SUMS"
echo "$(grep "${ISO_NAME}\$" SHA256SUMS | awk '{print $1}')  base.iso" | sha256sum -c -

echo "==> Extracting filesystem"
xorriso -osirrox on -indev base.iso -extract /casper/filesystem.squashfs base.squashfs
[ -s base.squashfs ] || { echo "filesystem.squashfs not found in ISO"; exit 1; }
unsquashfs -d chroot base.squashfs
rm -f base.squashfs

echo "==> Generating wallpaper"
convert -size 3840x2160 'radial-gradient:#0f3a34-#070b0f' wallpaper.png
mkdir -p chroot/usr/share/wallpapers/Novaria/contents/images
cp wallpaper.png chroot/usr/share/wallpapers/Novaria/contents/images/3840x2160.png
cat > chroot/usr/share/wallpapers/Novaria/metadata.json <<'EOF'
{
  "KPlugin": {
    "Id": "Novaria",
    "Name": "Novaria"
  }
}
EOF

echo "==> Preparing chroot"
mount --bind /dev chroot/dev
mount --bind /dev/pts chroot/dev/pts
mount -t proc proc chroot/proc
mount -t sysfs sys chroot/sys
mount --bind /run chroot/run
rm -f chroot/etc/resolv.conf
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > chroot/etc/resolv.conf

cp "$ROOT/customize.sh" chroot/tmp/customize.sh
echo "==> Customizing system (theme, icons, branding)"
chroot chroot bash /tmp/customize.sh

echo "==> Cleaning up chroot"
rm -f chroot/tmp/customize.sh
rm -f chroot/etc/resolv.conf
ln -s ../run/systemd/resolve/stub-resolv.conf chroot/etc/resolv.conf
chroot chroot dpkg-query -W --showformat='${Package}\t${Version}\n' > filesystem.manifest
cleanup
trap - EXIT

printf '%s' "$(du -sx --block-size=1 chroot | cut -f1)" > filesystem.size

echo "==> Building squashfs (this takes a while)"
mksquashfs chroot filesystem.squashfs -comp xz -b 1M -noappend
rm -rf chroot

echo "==> Building ISO"
OUT_ISO="$OUT/novaria-os-$(date +%Y%m%d).iso"
xorriso -indev base.iso -outdev "$OUT_ISO" \
  -volid "NOVARIA_OS" \
  -boot_image any replay \
  -map filesystem.squashfs /casper/filesystem.squashfs \
  -map filesystem.manifest /casper/filesystem.manifest \
  -map filesystem.size /casper/filesystem.size \
  -commit

chmod a+r "$OUT"/*.iso
ls -lh "$OUT"
echo "==> Done: $OUT_ISO"
