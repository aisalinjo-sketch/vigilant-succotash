#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$PROJECT_DIR"

printf 'Novo ime OS-a (npr. MojaDistribucija): '
IFS= read -r OS_NAME
[ -n "$OS_NAME" ] || { echo "Ime ne smije biti prazno." >&2; exit 1; }

printf 'Novo kratko ime za hostname i ID (npr. mojadistribucija): '
IFS= read -r OS_ID
[ -n "$OS_ID" ] || { echo "Kratko ime ne smije biti prazno." >&2; exit 1; }
case "$OS_ID" in
    *[!a-z0-9-]* ) echo "Koristi samo mala slova, brojeve i crtice." >&2; exit 1 ;;
esac

OS_NAME="$OS_NAME" OS_ID="$OS_ID" python3 - <<'PY'
import os
from pathlib import Path

root = Path.cwd()
name = os.environ["OS_NAME"]
os_id = os.environ["OS_ID"]
replacements = {"Novaria OS": name, "novariaos": os_id, "NOVARIAOS": os_id.upper(), "NOVARIA OS": name.upper()}
files = [
    root / "README.md",
    root / "Build.yml",
    root / ".github/workflows/Build.yml",
    root / "auto/config",
    root / "config/hooks/live/0100-branding.hook.chroot",
    root / "config/includes.chroot/etc/xdg/autostart/novariaos-first-login.desktop",
    root / "config/includes.chroot/usr/local/bin/novariaos-first-login",
    root / "config/includes.chroot/usr/share/novariaos/wallpaper/novariaos.svg",
]
for path in files:
    if path.exists():
        text = path.read_text()
        for old, new in replacements.items():
            text = text.replace(old, new)
        path.write_text(text)

old_asset = root / "config/includes.chroot/usr/share/novariaos"
new_asset = root / f"config/includes.chroot/usr/share/{os_id}"
if old_asset.exists() and old_asset != new_asset:
    old_asset.rename(new_asset)
old_wallpaper = new_asset / "wallpaper/novariaos.svg"
new_wallpaper = new_asset / f"wallpaper/{os_id}.svg"
if old_wallpaper.exists() and old_wallpaper != new_wallpaper:
    old_wallpaper.rename(new_wallpaper)
old_autostart = root / "config/includes.chroot/etc/xdg/autostart/novariaos-first-login.desktop"
new_autostart = old_autostart.with_name(f"{os_id}-first-login.desktop")
if old_autostart.exists() and old_autostart != new_autostart:
    old_autostart.rename(new_autostart)
old_helper = root / "config/includes.chroot/usr/local/bin/novariaos-first-login"
new_helper = old_helper.with_name(f"{os_id}-first-login")
if old_helper.exists() and old_helper != new_helper:
    old_helper.rename(new_helper)
PY

chmod +x config/includes.chroot/usr/local/bin/"$OS_ID"-first-login
printf 'Postavljeno ime: %s (%s)\n' "$OS_NAME" "$OS_ID"
printf 'Provjeri README i URL-ove prije javne distribucije.\n'
