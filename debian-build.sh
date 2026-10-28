#!/usr/bin/env bash
# Novaria OS (Debian base, built from scratch with live-build + KDE Plasma)
# Runs inside a debian:trixie container (see debian-build.yml).
set -euo pipefail

OS_NAME="Novaria OS"
SLUG="novaria"
ACCENT_RGB="0,201,167"
ACCENT_HEX="#00c9a7"

ROOT="$PWD"
BUILD="$ROOT/build"
OUT="$ROOT/out"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  live-build debootstrap xorriso squashfs-tools mtools dosfstools \
  grub-pc-bin grub-efi-amd64-bin syslinux syslinux-common isolinux syslinux-utils \
  imagemagick librsvg2-bin ca-certificates gnupg curl rsync file

rm -rf "$BUILD"
mkdir -p "$BUILD" "$OUT"
cd "$BUILD"

########################################################################
# 1. LOGO + GENERATED ARTWORK
########################################################################
mkdir -p assets
cat > assets/logo.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0d2a2f"/>
      <stop offset="1" stop-color="#05080c"/>
    </linearGradient>
    <linearGradient id="n" x1="0" y1="1" x2="1" y2="0">
      <stop offset="0" stop-color="#00c9a7"/>
      <stop offset="1" stop-color="#3ee6ff"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#7ffff0" stop-opacity="0.85"/>
      <stop offset="1" stop-color="#00c9a7" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="512" height="512" rx="112" fill="url(#bg)"/>
  <polygon transform="translate(-4 0)" fill="url(#n)"
    points="148,384 148,128 204,128 316,288 316,128 372,128 372,384 316,384 204,224 204,384"/>
  <circle cx="398" cy="114" r="74" fill="url(#glow)"/>
  <path fill="#ffffff" d="M398 62 Q404 108 450 114 Q404 120 398 166 Q392 120 346 114 Q392 108 398 62 Z"/>
</svg>
SVG

rsvg-convert -w 512 -h 512 assets/logo.svg -o assets/logo-512.png
rsvg-convert -w 256 -h 256 assets/logo.svg -o assets/logo-256.png
rsvg-convert -w 128 -h 128 assets/logo.svg -o assets/logo-128.png

IM="$(command -v magick || command -v convert)"

# Wallpaper: dark teal glow + faint logo watermark
$IM -size 3840x2160 'radial-gradient:#0f3a34-#05080c' \
  \( assets/logo-512.png -resize 1100x1100 -alpha set -channel A -evaluate multiply 0.10 +channel \) \
  -gravity center -composite assets/wallpaper.png

########################################################################
# 2. LIVE-BUILD CONFIG
########################################################################
lb config \
  --distribution trixie \
  --architectures amd64 \
  --archive-areas "main contrib non-free-firmware" \
  --apt-recommends false \
  --security true \
  --updates true \
  --linux-flavours amd64 \
  --firmware-chroot true \
  --firmware-binary true \
  --memtest none \
  --iso-application "$OS_NAME" \
  --iso-publisher "$OS_NAME" \
  --iso-volume "NOVARIA_OS" \
  --image-name "$SLUG" \
  --bootappend-live "boot=live components quiet splash hostname=$SLUG username=$SLUG user-fullname=$SLUG keyboard-layouts=hr locales=en_US.UTF-8"

########################################################################
# 3. PACKAGES
########################################################################
mkdir -p config/package-lists
cat > config/package-lists/novaria.list.chroot <<'EOF'
# --- Desktop: KDE Plasma ---
kde-plasma-desktop
sddm
kwin-x11
xserver-xorg
xwayland
plasma-nm
plasma-pa
powerdevil
kscreen
bluedevil
systemsettings
plasma-systemmonitor
xdg-desktop-portal-kde
kde-gtk-config
breeze-gtk-theme
kio-extras
plasma-discover
plasma-discover-backend-flatpak
flatpak

# --- Apps ---
konsole
dolphin
kate
ark
okular
gwenview
spectacle
firefox-esr
vlc
fastfetch
btop
git
curl

# --- Look ---
papirus-icon-theme
fonts-inter
fonts-jetbrains-mono
plymouth

# --- System ---
network-manager
bluez
pipewire-audio
wireplumber
sudo
locales
live-boot
live-config
live-config-systemd
firmware-linux
firmware-misc-nonfree
firmware-iwlwifi
firmware-realtek
firmware-atheros

# --- Installer ---
calamares
calamares-settings-debian
grub-efi-amd64
grub-pc-bin
efibootmgr
os-prober
parted
gdisk
dosfstools
e2fsprogs
btrfs-progs
EOF

########################################################################
# 4. FILES COPIED INTO THE SYSTEM (includes.chroot)
########################################################################
INC=config/includes.chroot
mkdir -p $INC/etc/sddm.conf.d $INC/etc/xdg/autostart $INC/usr/share/applications \
         $INC/usr/share/novaria $INC/usr/share/wallpapers/Novaria/contents/images \
         $INC/usr/share/plymouth/themes/novaria

cp assets/logo.svg     $INC/usr/share/novaria/logo.svg
cp assets/logo-512.png $INC/usr/share/novaria/logo-512.png
cp assets/logo-256.png $INC/usr/share/novaria/logo-256.png
cp assets/logo-128.png $INC/usr/share/novaria/logo-128.png
cp assets/wallpaper.png $INC/usr/share/wallpapers/Novaria/contents/images/3840x2160.png

cat > $INC/usr/share/wallpapers/Novaria/metadata.json <<'EOF'
{
  "KPlugin": {
    "Id": "Novaria",
    "Name": "Novaria"
  }
}
EOF

# Boot splash (Plymouth) with Novaria logo
cp assets/logo-256.png $INC/usr/share/plymouth/themes/novaria/logo.png
cat > $INC/usr/share/plymouth/themes/novaria/novaria.plymouth <<'EOF'
[Plymouth Theme]
Name=Novaria
Description=Novaria boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/novaria
ScriptFile=/usr/share/plymouth/themes/novaria/novaria.script
EOF
cat > $INC/usr/share/plymouth/themes/novaria/novaria.script <<'EOF'
Window.SetBackgroundTopColor(0.02, 0.03, 0.05);
Window.SetBackgroundBottomColor(0.02, 0.03, 0.05);
logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetX(Window.GetWidth() / 2 - logo.image.GetWidth() / 2);
logo.sprite.SetY(Window.GetHeight() / 2 - logo.image.GetHeight() / 2);
EOF

# Login screen: live session autologin into X11 (so the installer can run as root)
cat > $INC/etc/sddm.conf.d/10-novaria.conf <<EOF
[Theme]
Current=breeze

[Autologin]
User=$SLUG
Session=plasmax11
Relogin=false
EOF

# Installer launcher (appears on the desktop only in the live session)
cat > $INC/usr/share/applications/novaria-installer.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Install $OS_NAME
Comment=Install $OS_NAME on this computer
Exec=sudo -E calamares
Icon=/usr/share/novaria/logo-256.png
Terminal=false
NoDisplay=true
Categories=System;
EOF
cat > $INC/etc/xdg/autostart/novaria-live-icon.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Novaria live desktop icon
Exec=/bin/sh -c 'grep -q boot=live /proc/cmdline && mkdir -p "$HOME/Desktop" && cp /usr/share/applications/novaria-installer.desktop "$HOME/Desktop/" && chmod +x "$HOME/Desktop/novaria-installer.desktop"'
NoDisplay=true
OnlyShowIn=KDE;
EOF

########################################################################
# 5. HOOK: rebrand EVERYTHING, theme, installer, boot splash
########################################################################
mkdir -p config/hooks/live
HOOK=config/hooks/live/0100-novaria.hook.chroot
{
  printf 'OS_NAME="%s"\nSLUG="%s"\nACCENT_RGB="%s"\nACCENT_HEX="%s"\n' \
    "$OS_NAME" "$SLUG" "$ACCENT_RGB" "$ACCENT_HEX"
  cat <<'HOOK'
#!/bin/bash
set -e
export HOME=/root

echo "== os-release / issue / motd / hostname / grub =="
cat > /usr/lib/os-release <<EOF
PRETTY_NAME="$OS_NAME"
NAME="$OS_NAME"
VERSION_ID="1.0"
VERSION="1.0"
VERSION_CODENAME=trixie
ID=$SLUG
ID_LIKE=debian
LOGO=novaria
ANSI_COLOR="38;2;${ACCENT_RGB//,/;}"
EOF
echo "$OS_NAME \\n \\l" > /etc/issue
echo "$OS_NAME" > /etc/issue.net
printf '\n  %s\n\n' "$OS_NAME" > /etc/motd
echo "$SLUG" > /etc/hostname
sed -i "s/debian/$SLUG/g" /etc/hosts 2>/dev/null || true
if [ -f /etc/default/grub ]; then
  sed -i "s|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR=\"$OS_NAME\"|" /etc/default/grub
fi

echo "== Logo as system/start-menu icon =="
mkdir -p /usr/share/icons/hicolor/scalable/apps
cp /usr/share/novaria/logo.svg /usr/share/icons/hicolor/scalable/apps/novaria.svg
cp /usr/share/novaria/logo.svg /usr/share/icons/hicolor/scalable/apps/start-here-kde.svg
cp /usr/share/novaria/logo.svg /usr/share/icons/hicolor/scalable/apps/distributor-logo.svg
for f in $(find /usr/share/icons -name 'start-here*.svg' -o -name 'distributor-logo*.svg' 2>/dev/null); do
  rm -f "$f"; cp /usr/share/novaria/logo.svg "$f"
done
gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true

echo "== Color scheme =="
SCHEME_DIR=/usr/share/color-schemes
if [ -f "$SCHEME_DIR/BreezeDark.colors" ]; then
  sed "s/61,174,233/$ACCENT_RGB/g; s/^Name=.*/Name=Novaria Dark/" \
    "$SCHEME_DIR/BreezeDark.colors" > "$SCHEME_DIR/NovariaDark.colors"
fi

echo "== Default settings for every new user (/etc/skel) =="
mkdir -p /etc/skel/.config
KW=$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)
if [ -n "$KW" ]; then
  [ -f "$SCHEME_DIR/NovariaDark.colors" ] && cp "$SCHEME_DIR/NovariaDark.colors" /etc/skel/.config/kdeglobals
  K="$KW --file /etc/skel/.config/kdeglobals"
  $K --group General --key ColorScheme NovariaDark
  $K --group General --key AccentColor "$ACCENT_RGB"
  $K --group General --key font "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
  $K --group General --key menuFont "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
  $K --group General --key toolBarFont "Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
  $K --group General --key fixed "JetBrains Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
  $K --group Icons --key Theme Papirus-Dark
  $K --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop
  $KW --file /etc/skel/.config/kwinrc --group Plugins --key blurEnabled true
fi

echo "== Default wallpaper (desktop + lock screen) =="
for d in /usr/share/plasma/look-and-feel/*/contents; do
  [ -f "$d/defaults" ] && sed -i 's/^Image=.*/Image=Novaria/' "$d/defaults"
done

echo "== Login screen (SDDM) background =="
mkdir -p /usr/share/sddm/themes/breeze
printf '[General]\ntype=image\nbackground=/usr/share/wallpapers/Novaria/contents/images/3840x2160.png\n' \
  > /usr/share/sddm/themes/breeze/theme.conf.user

echo "== Boot splash =="
if [ -d /usr/share/plymouth/themes/novaria ]; then
  plymouth-set-default-theme novaria || true
  update-initramfs -u -k all || true
fi

echo "== Installer (Calamares) branding =="
if [ -d /etc/calamares/branding/debian ]; then
  cp -r /etc/calamares/branding/debian "/etc/calamares/branding/$SLUG"
  B="/etc/calamares/branding/$SLUG"
  sed -i -E "s/^([[:space:]]*)(productName|shortProductName|versionedName|shortVersionedName|bootloaderEntryName):.*/\1\2: \"$OS_NAME\"/" "$B/branding.desc"
  sed -i -E 's/^([[:space:]]*sidebarBackground:).*/\1 "#0b1216"/; s/^([[:space:]]*sidebarText:).*/\1 "#e6fffa"/; s/^([[:space:]]*sidebarTextSelect:).*/\1 "#00c9a7"/; s/^([[:space:]]*sidebarTextHighlight:).*/\1 "#00c9a7"/' "$B/branding.desc"
  for key in productLogo productIcon productWelcome; do
    img=$(grep -E "^[[:space:]]*$key:" "$B/branding.desc" | head -1 | sed -E 's/^[^:]*:[[:space:]]*"?([^"]*)"?.*/\1/')
    if [ -n "$img" ]; then
      case "$key" in
        productWelcome)
          convert -size 1200x600 xc:'#0b1216' /usr/share/novaria/logo-256.png -gravity center -composite "$B/$img" 2>/dev/null || cp /usr/share/novaria/logo-256.png "$B/$img" ;;
        *)
          cp /usr/share/novaria/logo-256.png "$B/$img" ;;
      esac
    fi
  done
  cat > "$B/show.qml" <<'QML'
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation
    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0b1216"
            Text {
                anchors.centerIn: parent
                text: "Welcome to Novaria OS"
                color: "#00c9a7"
                font.pixelSize: 28
            }
        }
    }
}
QML
  [ -f /etc/calamares/settings.conf ] && sed -i -E "s/^branding:.*/branding: $SLUG/" /etc/calamares/settings.conf
  rm -rf /etc/calamares/branding/debian
fi

echo "== Remove leftover visible branding text =="
grep -rIl -i "debian" /usr/share/applications /etc/xdg/autostart /etc/calamares 2>/dev/null \
  | xargs -r sed -i "s/Debian GNU\/Linux/$OS_NAME/g; s/Debian/$OS_NAME/g" || true
if dpkg -s desktop-base >/dev/null 2>&1; then
  rm -rf /usr/share/desktop-base/*-theme /usr/share/desktop-base/debian-logos 2>/dev/null || true
fi

echo "== Shell: prompt + fastfetch =="
cat >> /etc/skel/.bashrc <<'BASHRC'

# Novaria shell
PS1='\[\e[38;2;0;201;167m\]\u\[\e[0m\]@\[\e[38;2;62;230;255m\]\h\[\e[0m\] \w \[\e[38;2;0;201;167m\]>\[\e[0m\] '
alias ll='ls -lah --color=auto'
command -v fastfetch >/dev/null 2>&1 && [ -t 1 ] && fastfetch
BASHRC

echo "== Flathub =="
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

rm -f /root/os.env 2>/dev/null || true
echo "== Hook done =="
HOOK
} > "$HOOK"
chmod +x "$HOOK"

########################################################################
# 6. BOOT MENU (isolinux / GRUB) rebrand
########################################################################
mkdir -p config/bootloaders
cp -r /usr/share/live/build/bootloaders/* config/bootloaders/ || true
set +e
grep -rIl "Debian" config/bootloaders 2>/dev/null \
  | xargs -r sed -i "s/Debian GNU\/Linux/$OS_NAME/g; s/Debian Live/$OS_NAME Live/g; s/Debian/$OS_NAME/g"
for f in $(find config/bootloaders -type f \( -name 'splash.png' -o -name 'background.png' \)); do
  size=$(identify -format '%wx%h' "$f" 2>/dev/null)
  [ -z "$size" ] && continue
  $IM -size "$size" xc:'#05080c' \( "$ROOT/build/assets/logo-128.png" \) \
    -gravity NorthEast -geometry +20+20 -composite "$f"
done
for f in $(find config/bootloaders -type f -name 'splash.svg'); do
  B64=$(base64 -w0 assets/logo-128.png)
  cat > "$f" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="640" height="480" viewBox="0 0 640 480">
  <rect width="640" height="480" fill="#05080c"/>
  <image x="492" y="20" width="128" height="128" href="data:image/png;base64,$B64"/>
</svg>
SVG
done
set -e

########################################################################
# 7. BUILD
########################################################################
lb build 2>&1 | tee "$ROOT/build.log"

find "$BUILD" -maxdepth 1 -name '*.iso' -exec cp {} "$OUT"/ \;
chmod -R a+rX "$OUT"
ls -lh "$OUT"
echo "== Done =="
