#!/usr/bin/env bash
# Runs INSIDE the Kubuntu chroot. Applies Novaria OS look (CachyOS-like dark + teal accent) + gaming setup.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive HOME=/root LC_ALL=C

OS_NAME="Novaria OS"
ACCENT_RGB="0,201,167"     # teal/green accent, change to taste (R,G,B)

echo "-- Enabling repositories (universe, multiverse) and 32-bit support"
add-apt-repository -y universe || true
add-apt-repository -y multiverse || true
dpkg --add-architecture i386
apt-get update

echo "-- Installing icons and fonts"
apt-get install -y papirus-icon-theme fonts-inter

echo "-- Gaming: Steam license preseed"
echo "steam steam/question select I AGREE" | debconf-set-selections
echo "steam steam/license note ''" | debconf-set-selections

echo "-- Gaming: packages (each one separately, a missing package will not stop the build)"
for p in \
  steam-installer steam-devices \
  lutris wine winetricks \
  gamemode mangohud \
  vulkan-tools mesa-vulkan-drivers mesa-vulkan-drivers:i386 libgl1-mesa-dri:i386 \
  corectrl radeontop \
  obs-studio vlc libavcodec-extra \
  flatpak plasma-discover-backend-flatpak ; do
  apt-get install -y "$p" || echo "WARN: could not install $p"
done

echo "-- Gaming: Flathub (for Heroic, Discord, ProtonUp-Qt etc. via Discover)"
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

echo "-- Gaming: system tweaks"
cat > /etc/sysctl.d/99-novaria-gaming.conf <<'EOF'
# Needed by many modern games (Proton)
vm.max_map_count = 2147483642
vm.swappiness = 10
EOF

echo "-- Gaming: MangoHud default overlay (toggle with Right Shift + F12)"
mkdir -p /etc/skel/.config/MangoHud
cat > /etc/skel/.config/MangoHud/MangoHud.conf <<'EOF'
fps
frametime
cpu_stats
gpu_stats
position=top-left
toggle_hud=Shift_R+F12
EOF

echo "-- Gaming: NVIDIA driver helper (menu entry)"
cat > /usr/share/applications/novaria-gpu-drivers.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Install graphics drivers (NVIDIA)
Comment=Installs the recommended proprietary graphics driver. Needs internet.
Exec=sudo ubuntu-drivers install
Icon=preferences-desktop-display
Terminal=true
Categories=System;Settings;
EOF

echo "-- Branding"
sed -i "s/^NAME=.*/NAME=\"$OS_NAME\"/; s/^PRETTY_NAME=.*/PRETTY_NAME=\"$OS_NAME\"/" /usr/lib/os-release
echo "$OS_NAME \\n \\l" > /etc/issue
echo "$OS_NAME" > /etc/issue.net

echo "-- Color scheme (Breeze Dark with Novaria accent)"
SCHEME_DIR=/usr/share/color-schemes
sed "s/61,174,233/$ACCENT_RGB/g; s/^Name=.*/Name=Novaria Dark/" \
  "$SCHEME_DIR/BreezeDark.colors" > "$SCHEME_DIR/NovariaDark.colors"

echo "-- Default settings for every new user (/etc/skel)"
mkdir -p /etc/skel/.config
cp "$SCHEME_DIR/NovariaDark.colors" /etc/skel/.config/kdeglobals
KW="kwriteconfig5 --file /etc/skel/.config/kdeglobals"
$KW --group General --key ColorScheme NovariaDark
$KW --group Icons --key Theme Papirus-Dark
$KW --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop

echo "-- Default wallpaper"
for d in /usr/share/plasma/look-and-feel/org.kde.breeze.desktop /usr/share/plasma/look-and-feel/org.kde.breezedark.desktop; do
  if [ -f "$d/contents/defaults" ]; then
    sed -i 's/^Image=.*/Image=Novaria/' "$d/contents/defaults"
  fi
done

echo "-- Cleanup"
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /root/.bash_history || true
