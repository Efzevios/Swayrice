#!/usr/bin/env bash
set -Eeuo pipefail

# KDE Connect: ponte RemoteDesktop para Sway / Debian 13.
# Instala apenas na conta do usuario (~/.local).

REPO_URL='https://github.com/gfhdhytghd/hypr-kdeconnect-fix.git'
PREFIX="$HOME/.local"
PORTAL_DIR="$HOME/.config/xdg-desktop-portal"
PORTAL_CONF="$PORTAL_DIR/sway-portals.conf"
REMOTE_KEY='org.freedesktop.impl.portal.RemoteDesktop'
REMOTE_VALUE='hypr-kdeconnect'

info() { printf '\n=> %s\n' "$*"; }
warn() { printf 'Aviso: %s\n' "$*" >&2; }

# Define uma chave dentro de [preferred], preservando as outras configuracoes.
set_preferred_key() {
    local file="$1" key="$2" value="$3" tmp
    tmp="$(mktemp "${file}.XXXXXX")"
    awk -v target="$key" -v val="$value" '
      BEGIN { inside=0; section_seen=0; key_written=0 }
      /^\[[^]]+\][[:space:]]*$/ {
          if (inside && !key_written) { print target "=" val; key_written=1 }
          inside=($0 ~ /^\[preferred\][[:space:]]*$/)
          if (inside) section_seen=1
          print
          next
      }
      inside && index($0, "=") {
          split($0, fields, "=")
          k=fields[1]
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
          if (k == target) {
              if (!key_written) { print target "=" val; key_written=1 }
              next
          }
      }
      { print }
      END {
          if (!section_seen) { print ""; print "[preferred]"; print target "=" val }
          else if (inside && !key_written) print target "=" val
      }
    ' "$file" > "$tmp"
    chmod --reference="$file" "$tmp"
    mv -f "$tmp" "$file"
}

info 'Instalando dependencias (Debian 13)...'
sudo apt-get update
sudo apt-get install -y \
    git cmake build-essential pkg-config \
    qt6-base-dev qt6-base-private-dev \
    libwayland-dev libxkbcommon-dev wayland-protocols \
    libei-dev libeis-dev \
    meson ninja-build python3 python3-jinja2 \
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr

info 'Clonando o projeto com todos os submodulos...'
WORKDIR="$(mktemp -d -t hypr-kdeconnect-fix.XXXXXXXX)"
trap 'rm -rf -- "$WORKDIR"' EXIT

git clone --recurse-submodules "$REPO_URL" "$WORKDIR/src"
cd "$WORKDIR/src"
# Garante que nenhum submodulo tenha ficado vazio apos o clone.
git submodule update --init --recursive

# Nao reduzir os requisitos de versao e nao alterar security_policy.hpp:
# no Debian 13, o proprio projeto compila a libei incluida como submodulo.
info 'Compilando e instalando em ~/.local...'
cmake -S . -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX"
# Mantemos os IDs padrão em HKCF_PORTAL_USE_IN. O teste oficial
# portal-metadata-test exige wlroots, Hyprland, sway, Wayfire,
# river, phosh, niri e labwc, mesmo quando a sessão ativa é sway.
cmake --build build --parallel "$(nproc)"
ctest --test-dir build --output-on-failure
cmake --install build

info 'Configurando o backend RemoteDesktop somente para Sway...'
mkdir -p "$PORTAL_DIR"

if [[ ! -e "$PORTAL_CONF" ]]; then
    if [[ -f "$PORTAL_DIR/portals.conf" ]]; then
        # Preserva o conjunto de preferencias que o usuario ja utiliza.
        cp "$PORTAL_DIR/portals.conf" "$PORTAL_CONF"
    else
        cat > "$PORTAL_CONF" <<'PORTALS'
[preferred]
default=gtk
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.Screenshot=wlr
PORTALS
    fi
else
    cp -p "$PORTAL_CONF" "${PORTAL_CONF}.bak.$(date +%Y%m%d-%H%M%S)"
fi
set_preferred_key "$PORTAL_CONF" "$REMOTE_KEY" "$REMOTE_VALUE"

info 'Disponibilizando os metadados em ~/.local/share para o systemd e D-Bus...'
mkdir -p "$HOME/.config/environment.d"
# environment.d admite expansao ${VAR:-padrao}, mas nao e um shell script.
printf 'XDG_DATA_DIRS=%s/.local/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\n' \
    "$HOME" > "$HOME/.config/environment.d/90-hypr-kdeconnect.conf"

case ":${XDG_DATA_DIRS:-}:" in
    *":$HOME/.local/share:"*) ;;
    *) export XDG_DATA_DIRS="$HOME/.local/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" ;;
esac
systemctl --user set-environment "XDG_DATA_DIRS=$XDG_DATA_DIRS"
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd XDG_DATA_DIRS || \
        warn 'Nao foi possivel atualizar o ambiente de ativacao do D-Bus.'
fi

info 'Recarregando os portais...'
systemctl --user daemon-reload
# Evita manter uma instancia antiga do backend apos reinstalar.
systemctl --user stop hypr-kdeconnect-portal.service 2>/dev/null || true
systemctl --user restart xdg-desktop-portal

# KDE Connect conserva sessoes RemoteDesktop antigas apos reiniciar o portal.
if command -v kquitapp6 >/dev/null 2>&1; then
    kquitapp6 kdeconnectd >/dev/null 2>&1 || true
else
    pkill -x kdeconnectd 2>/dev/null || true
fi

printf '\n==========================================================\n'
printf 'Instalacao concluida. Abra novamente o KDE Connect no computador\n'
printf 'e a funcao Entrada remota no celular.\n'
printf 'Configuracao: %s\n' "$PORTAL_CONF"
printf 'Teste de interface: busctl --user introspect org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.portal.RemoteDesktop\n'
printf '==========================================================\n'
