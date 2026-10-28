#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$PROJECT_DIR"

if ! command -v lb >/dev/null 2>&1; then
    echo "live-build nije instaliran. Pokreni: sudo apt install live-build debootstrap" >&2
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    echo "Build.sh nemoj pokretati kao root; skripta će koristiti sudo samo za izradu." >&2
    exit 1
fi

lb config
sudo lb build

echo "ISO je izrađen u: $PROJECT_DIR"
