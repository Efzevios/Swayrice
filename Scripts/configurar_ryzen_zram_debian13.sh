#!/usr/bin/env bash
# Ryzen 3 PRO 4350G + Debian 13 (systemd)
# Configura AMD P-State EPP e ZRAM de forma persistente e idempotente.
# Uso: sudo bash configurar_ryzen_zram_debian13.sh
#      bash configurar_ryzen_zram_debian13.sh --status
set -Eeuo pipefail

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
readonly SERVICE=/etc/systemd/system/amd-epp.service
readonly HELPER=/usr/local/libexec/amd-epp-configure
readonly ZRAM_CONF=/etc/systemd/zram-generator.conf.d/99-ryzen4350g-zram.conf
readonly CPU_PATH=/sys/devices/system/cpu/cpufreq
readonly STAMP="$(date +%Y%m%d-%H%M%S)"
TMPDIR_CUSTOM=''

info() { printf '\n[INFO] %s\n' "$*"; }
warn() { printf '\n[AVISO] %s\n' "$*" >&2; }
die() { printf '\n[ERRO] %s\n' "$*" >&2; exit 1; }
cleanup() { if [[ -n "$TMPDIR_CUSTOM" ]]; then rm -rf -- "$TMPDIR_CUSTOM"; fi; }
trap cleanup EXIT

status() {
    echo '========== AMD P-State =========='
    if [[ -r "$CPU_PATH/policy0/scaling_driver" ]]; then
        printf 'Driver: %s\n' "$(cat "$CPU_PATH/policy0/scaling_driver")"
        for p in "$CPU_PATH"/policy*; do
            [[ -d "$p" ]] || continue
            governor=$(cat "$p/scaling_governor" 2>/dev/null || printf 'N/D')
            epp=$(cat "$p/energy_performance_preference" 2>/dev/null || printf 'N/D')
            printf '%-9s governador=%-12s EPP=%s\n' "${p##*/}" "$governor" "$epp"
        done
    else
        echo 'Políticas de frequência não disponíveis.'
    fi
    if [[ -r "$CPU_PATH/boost" ]]; then
        printf 'Boost: %s\n' "$(cat "$CPU_PATH/boost")"
    else
        echo 'Boost: interface global não disponível.'
    fi
    echo
    echo '========== Serviços =========='
    systemctl is-enabled amd-epp.service 2>/dev/null || true
    systemctl is-active amd-epp.service 2>/dev/null || true
    echo
    echo '========== Swap / ZRAM =========='
    swapon --show || true
    if command -v zramctl >/dev/null 2>&1; then zramctl || true; fi
    if [[ -r /sys/block/zram0/comp_algorithm ]]; then
        printf 'Algoritmos ZRAM: %s\n' "$(cat /sys/block/zram0/comp_algorithm)"
    fi
    if [[ -r /proc/sys/vm/swappiness ]]; then
        printf 'vm.swappiness (mantido): %s\n' "$(cat /proc/sys/vm/swappiness)"
    fi
}

usage() {
    cat <<'USAGE'
Configuração de CPU + ZRAM para Debian 13 com AMD P-State EPP.

Uso:
  sudo bash configurar_ryzen_zram_debian13.sh
  bash configurar_ryzen_zram_debian13.sh --status
  bash configurar_ryzen_zram_debian13.sh --help

Configura:
  - amd-pstate-epp / powersave / balance_performance
  - Boost habilitado, se o kernel oferecer controle global
  - ZRAM com zstd, tamanho min(RAM/2, 4096 MiB), prioridade 100

Não troca o driver do kernel nem mexe nas partições Btrfs.
Não desativa um swap em disco nem altera vm.swappiness.
Arquivos diferentes que forem substituídos ganham backup *.backup-DATA.
USAGE
}

case "${1:-}" in
    --help|-h) usage; exit 0 ;;
    --status) status; exit 0 ;;
    '') ;;
    *) usage; die "Argumento desconhecido: $1" ;;
esac

[[ $EUID -eq 0 ]] || die 'Execute com sudo: sudo bash configurar_ryzen_zram_debian13.sh'
[[ -r /etc/os-release ]] || die 'Não foi possível identificar a distribuição.'
# shellcheck disable=SC1091
. /etc/os-release
[[ "${ID:-}" == debian && "${VERSION_ID:-}" == 13 ]] || die 'Este script foi preparado somente para Debian 13 (trixie).'
command -v systemctl >/dev/null || die 'systemd não está disponível.'
[[ "$(cat "$CPU_PATH/policy0/scaling_driver" 2>/dev/null || true)" == amd-pstate-epp ]] || die 'Driver ativo diferente de amd-pstate-epp. Nenhuma configuração foi modificada.'
[[ -d "$CPU_PATH" ]] || die 'Diretório de políticas de CPU não encontrado.'

# Validar que todas as políticas podem receber os valores desejados antes de modificar arquivos.
found=0
for p in "$CPU_PATH"/policy*; do
    [[ -d "$p" ]] || continue
    ((found += 1))
    [[ "$(cat "$p/scaling_driver" 2>/dev/null || true)" == amd-pstate-epp ]] || die "Driver inesperado em ${p##*/}."
    [[ -w "$p/scaling_governor" && -w "$p/energy_performance_preference" ]] || die "Sem permissão de escrita em ${p##*/}."
    grep -qw powersave "$p/scaling_available_governors" || die "O governador powersave não está disponível em ${p##*/}."
    grep -qw balance_performance "$p/energy_performance_available_preferences" || die "O EPP balance_performance não está disponível em ${p##*/}."
done
(( found > 0 )) || die 'Nenhuma política de frequência foi encontrada.'

# Evitar duas ferramentas tentando controlar o mesmo recurso.
for service in power-profiles-daemon.service tuned.service tlp.service; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        die "O serviço $service está ativo. Desative-o ou adapte o script antes de continuar."
    fi
done
if systemctl is-active --quiet zramswap.service 2>/dev/null; then
    die 'O serviço zramswap (zram-tools) está ativo. Não serão criados dispositivos ZRAM concorrentes.'
fi
if dpkg-query -W -f='${Status}' zram-tools 2>/dev/null | grep -q 'install ok installed'; then
    die 'O pacote zram-tools está instalado. Avalie a configuração existente antes de usar systemd-zram-generator.'
fi
if grep -Eq '(^|[[:space:]])systemd\.zram=0([[:space:]]|$)' /proc/cmdline; then
    die 'O kernel foi iniciado com systemd.zram=0; remova essa opção antes de configurar ZRAM.'
fi

# Não sobrescrever uma configuração de ZRAM preexistente de outra ferramenta.
# Reexecutar o próprio script continua permitido.
for dir in /etc/systemd/zram-generator.conf.d /run/systemd/zram-generator.conf.d \
           /usr/lib/systemd/zram-generator.conf.d /usr/local/lib/systemd/zram-generator.conf.d; do
    [[ -d "$dir" ]] || continue
    for config in "$dir"/*.conf; do
        [[ -e "$config" ]] || continue
        [[ "$config" == "$ZRAM_CONF" ]] && continue
        if grep -Eq '^\[zram0\][[:space:]]*$' "$config"; then
            die "Outra configuração de zram0 foi encontrada em $config. Revise-a primeiro."
        fi
    done
done
for config in /etc/systemd/zram-generator.conf /run/systemd/zram-generator.conf \
              /usr/local/lib/systemd/zram-generator.conf; do
    [[ -f "$config" ]] || continue
    if grep -Eq '^\[zram0\][[:space:]]*$' "$config"; then
        die "Outra configuração de zram0 foi encontrada em $config. Revise-a primeiro."
    fi
done
# O arquivo /usr/lib/systemd/zram-generator.conf pertence ao pacote Debian 13
# e pode conter uma secao [zram0] padrao. Nosso drop-in /etc/.../99-...
# substitui somente tamanho, algoritmo e prioridade, sem editar o fornecedor.

# Não redefinir dispositivos ZRAM já em uso: desligar swap pode causar perda de páginas.
if swapon --noheadings --show=NAME 2>/dev/null | grep -Eq '(^|/)zram[0-9]+$'; then
    if [[ ! -f "$ZRAM_CONF" ]]; then
        die 'Já existe ZRAM em uso, mas não foi configurada por este script.'
    fi
    warn 'ZRAM já está ativa: a configuração dela não será reaplicada em tempo real. Reinicie para garantir os valores.'
    ZRAM_ALREADY_ACTIVE=1
else
    ZRAM_ALREADY_ACTIVE=0
fi

# Criar arquivos de maneira repetível; guardar backups quando houver diferenças.
TMPDIR_CUSTOM=$(mktemp -d)
write_file() {
    local destination="$1" mode="$2" source="$3"
    install -d -m 0755 "$(dirname "$destination")"
    if [[ -e "$destination" ]]; then
        if cmp -s "$source" "$destination"; then
            info "Já configurado: $destination"
            return 0
        fi
        local backup="${destination}.backup-${STAMP}"
        [[ ! -e "$backup" ]] || backup="${backup}-$$"
        cp -a -- "$destination" "$backup"
        info "Backup: $backup"
    fi
    install -m "$mode" "$source" "$destination"
    info "Gravado: $destination"
}

if [[ -r /sys/module/zswap/parameters/enabled ]] &&
   [[ "$(cat /sys/module/zswap/parameters/enabled)" == Y ]]; then
    warn 'Zswap está ativo. Zswap e ZRAM são mecanismos diferentes de compressão; confira se deseja manter ambos. O script não altera o boot.'
fi

info 'Instalando systemd-zram-generator (sem atualizar todo o sistema)...' 
DEBIAN_FRONTEND=noninteractive apt-get install -y systemd-zram-generator

cat > "$TMPDIR_CUSTOM/amd-epp-configure" <<'HELPER'
#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob
base=/sys/devices/system/cpu/cpufreq
count=0
for p in "$base"/policy*; do
    [[ -d "$p" ]] || continue
    [[ "$(cat "$p/scaling_driver" 2>/dev/null || true)" == amd-pstate-epp ]] || continue
    grep -qw powersave "$p/scaling_available_governors" || continue
    grep -qw balance_performance "$p/energy_performance_available_preferences" || continue
    # O governador é aplicado primeiro porque alterná-lo pode redefinir o EPP.
    if [[ "$(cat "$p/scaling_governor")" != powersave ]]; then
        printf '%s\n' powersave > "$p/scaling_governor"
    fi
    if [[ "$(cat "$p/energy_performance_preference")" != balance_performance ]]; then
        printf '%s\n' balance_performance > "$p/energy_performance_preference"
    fi
    ((count += 1))
done
((count > 0)) || { echo 'Nenhuma política amd-pstate-epp compatível encontrada.' >&2; exit 1; }
if [[ -w "$base/boost" && "$(cat "$base/boost")" != 1 ]]; then
    printf '1\n' > "$base/boost"
fi
printf 'AMD EPP configurado em %d políticas; Boost: %s\n' "$count" "$(cat "$base/boost" 2>/dev/null || echo 'N/D')"
HELPER
write_file "$HELPER" 0755 "$TMPDIR_CUSTOM/amd-epp-configure"

cat > "$TMPDIR_CUSTOM/amd-epp.service" <<'SERVICE'
[Unit]
Description=AMD P-State EPP - powersave e balance_performance
ConditionPathExists=/sys/devices/system/cpu/cpufreq/policy0/scaling_driver
After=systemd-udevd.service

[Service]
Type=oneshot
ExecStart=/usr/local/libexec/amd-epp-configure
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE
write_file "$SERVICE" 0644 "$TMPDIR_CUSTOM/amd-epp.service"

cat > "$TMPDIR_CUSTOM/zram.conf" <<'ZRAM'
# Debian 13: ZRAM com ZSTD, sem swap em disco adicional.
# Tamanho lógico: metade da RAM, limitado a 4096 MiB (~4 GiB).
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
ZRAM
write_file "$ZRAM_CONF" 0644 "$TMPDIR_CUSTOM/zram.conf"

info 'Recarregando systemd e aplicando as configurações...'
systemctl daemon-reload
systemctl enable --now amd-epp.service
# Um oneshot com RemainAfterExit=yes não reexecuta ao chamar start novamente.
systemctl restart amd-epp.service

if [[ "$ZRAM_ALREADY_ACTIVE" == 0 ]]; then
    if ! systemctl start dev-zram0.swap; then
        warn 'A ZRAM não iniciou. Verifique: journalctl -u systemd-zram-setup@zram0.service -b --no-pager'
        die 'Configuração gravada, mas o swap em ZRAM não pôde ser iniciado. Confira o erro antes de reiniciar.'
    fi
fi

info 'Verificação final'
status
if [[ -r /sys/block/zram0/comp_algorithm ]]; then
    algorithm=$(grep -oE '\[[^]]+\]' /sys/block/zram0/comp_algorithm | head -n 1 || true)
    if [[ "$algorithm" == '[zstd]' ]]; then
        info 'Compressão ZRAM confirmada: ZSTD.'
    else
        warn "A ZRAM está configurada para ZSTD, mas o algoritmo atual é ${algorithm:-desconhecido}. Verifique o suporte do kernel."
    fi
fi
printf '\n[OK] Configuração persistente aplicada. ZRAM: tamanho lógico de até 4 GiB.\n' 
printf 'Dica: após reiniciar, consulte: bash %q --status\n' "$(realpath "$0")"
