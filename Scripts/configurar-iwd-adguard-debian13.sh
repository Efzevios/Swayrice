#!/usr/bin/env bash
# Configura o iwd e o AdGuard DNS no Debian 13 (Trixie).
# Prefere DNS-over-TLS somente via IPv4 (sem desativar IPv6 do sistema).
# Uso: sudo bash iwd-adguard-debian13.sh [--sem-tls]
# Restauração: sudo bash iwd-adguard-debian13.sh --restaurar /var/backups/iwd-adguard-...
set -Eeuo pipefail

# =====================
# I. Preparação
# =====================
## I. Requisitos de execução
### I.I. Exige privilégios administrativos
if (( EUID != 0 )); then
    printf 'Erro: execute com sudo.\n' >&2
    exit 1
fi
### I.II. Confere as ferramentas básicas do Debian
for comando in apt-get dpkg-query systemctl awk install getent; do
    if ! command -v "$comando" >/dev/null 2>&1; then
        printf 'Erro: comando obrigatório não encontrado: %s\n' "$comando" >&2
        exit 1
    fi
done

## II. Arquivos e endereços utilizados
### II.I. Caminhos das configurações do sistema
IWD_CONF='/etc/iwd/main.conf'
RESOLVED_CONF='/etc/systemd/resolved.conf.d/90-adguard.conf'
RESOLV_CONF='/etc/resolv.conf'
### II.II. Servidores públicos do AdGuard com bloqueio de anúncios e rastreadores
ADGUARD_1='94.140.14.14'
ADGUARD_2='94.140.15.15'
ADGUARD_TLS='dns.adguard-dns.com'

## III. Opções disponíveis
### III.I. Por padrão, exige DNS-over-TLS; --sem-tls mantém o AdGuard sem criptografia
MODO_TLS='yes'
if [[ ${1:-} == '--sem-tls' && $# -eq 1 ]]; then
    MODO_TLS='no'
elif [[ ${1:-} == '--restaurar' && $# -eq 2 ]]; then
    DIRETORIO_RESTAURACAO=$2
    if [[ ! -f "$DIRETORIO_RESTAURACAO/backup-iwd-adguard" ]]; then
        printf 'Erro: pasta de backup inválida: %s\n' "$DIRETORIO_RESTAURACAO" >&2
        exit 1
    fi

    # =====================
    # II. Restauração
    # =====================
    ## I. Recupera os arquivos originais e suas permissões
    ### I.I. Se um arquivo não existia antes, remove a versão criada pelo script
    for nome in resolv.conf main.conf 90-adguard.conf; do
        case "$nome" in
            resolv.conf) destino=$RESOLV_CONF ;;
            main.conf) destino=$IWD_CONF ;;
            90-adguard.conf) destino=$RESOLVED_CONF ;;
        esac
        if [[ -e "$DIRETORIO_RESTAURACAO/$nome" || -L "$DIRETORIO_RESTAURACAO/$nome" ]]; then
            mkdir -p "$(dirname "$destino")"
            rm -f -- "$destino"
            cp -a -- "$DIRETORIO_RESTAURACAO/$nome" "$destino"
        else
            rm -f -- "$destino"
        fi
    done
    ## II. Recarrega os serviços em execução
    ### II.I. Preserva o estado de habilitação dos serviços
    for servico in systemd-resolved.service iwd.service; do
        if systemctl is-active --quiet "$servico"; then
            systemctl restart "$servico"
        fi
    done
    printf '\nConfigurações restauradas de: %s\n' "$DIRETORIO_RESTAURACAO"
    printf 'Observação: os pacotes instalados não são removidos pela restauração.\n'
    exit 0
elif (( $# != 0 )); then
    printf 'Uso: sudo bash %s [--sem-tls]\n' "$0" >&2
    printf '     sudo bash %s --restaurar /var/backups/iwd-adguard-...\n' "$0" >&2
    exit 1
fi

## IV. Segurança e cópias de backup
### IV.I. Evita acesso não autorizado aos arquivos copiados
umask 077
BACKUP_DIR="/var/backups/iwd-adguard-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$BACKUP_DIR"
printf 'Backup do configurador de iwd e AdGuard DNS\n' > "$BACKUP_DIR/backup-iwd-adguard"
### IV.II. Preserva arquivos e links simbólicos existentes
salvar_original() {
    local origem=$1 nome=$2
    if [[ -e "$origem" || -L "$origem" ]]; then
        cp -aP -- "$origem" "$BACKUP_DIR/$nome"
    fi
}
salvar_original "$RESOLV_CONF" 'resolv.conf'
salvar_original "$IWD_CONF" 'main.conf'
salvar_original "$RESOLVED_CONF" '90-adguard.conf'
### IV.III. Remove arquivos temporários quando necessário
ARQUIVO_TEMP=''
limpar_temporarios() {
    if [[ -n "$ARQUIVO_TEMP" && -f "$ARQUIVO_TEMP" ]]; then
        rm -f -- "$ARQUIVO_TEMP"
    fi
}
trap limpar_temporarios EXIT
trap 'printf "\nErro na linha %s. Backup disponível em: %s\n" "$LINENO" "$BACKUP_DIR" >&2' ERR

# =====================
# III. Instalação
# =====================
## I. Recuperação temporária do DNS para usar o APT
### I.I. Só substitui o DNS provisoriamente caso a resolução atual esteja falhando
printf '\n[1/6] Verificando a resolução de nomes...\n'
if ! getent ahostsv4 debian.org >/dev/null 2>&1; then
    printf 'DNS indisponível. Aplicando temporariamente os servidores do AdGuard.\n'
    rm -f -- "$RESOLV_CONF"
    printf 'nameserver %s\nnameserver %s\n' "$ADGUARD_1" "$ADGUARD_2" > "$RESOLV_CONF"
    chmod 644 "$RESOLV_CONF"
    if ! getent ahostsv4 debian.org >/dev/null 2>&1; then
        printf 'Erro: nem o DNS temporário conseguiu resolver debian.org.\n' >&2
        printf 'Verifique o Wi-Fi e a rota padrão com: ip route\n' >&2
        printf 'Backup: %s\n' "$BACKUP_DIR" >&2
        exit 2
    fi
fi

## II. Instalação dos pacotes necessários
### II.I. Evita atualizar os repositórios se os pacotes já estiverem instalados
printf '\n[2/6] Verificando os pacotes iwd, systemd-resolved e ca-certificates...\n'
pacotes_pendentes=()
for pacote in iwd systemd-resolved ca-certificates; do
    if [[ $(dpkg-query -W -f='${Status}' "$pacote" 2>/dev/null || :) != 'install ok installed' ]]; then
        pacotes_pendentes+=("$pacote")
    fi
done
if (( ${#pacotes_pendentes[@]} > 0 )); then
    apt-get -o Acquire::ForceIPv4=true update
    apt-get -o Acquire::ForceIPv4=true install -y "${pacotes_pendentes[@]}"
else
    printf 'Os pacotes já estão instalados.\n'
fi

# =====================
# IV. Configuração
# =====================
## I. iwd como gerenciador de redes sem fio
### I.I. Ativa DHCP e IPv6 internos, sem receber DNS do roteador
printf '\n[3/6] Configurando o iwd...\n'
mkdir -p /etc/iwd
ORIGEM='/dev/null'
if [[ -f "$IWD_CONF" ]]; then
    ORIGEM=$IWD_CONF
fi
ARQUIVO_TEMP=$(mktemp)
### I.II. Mantém outras seções e opções já existentes no main.conf
awk '
function encerrar_secao() {
    if (secao == "[General]") print "EnableNetworkConfiguration=true"
    if (secao == "[Network]") {
        print "EnableIPv6=true"
        print "NameResolvingService=none"
    }
}
/^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
    encerrar_secao()
    secao = $0
    gsub(/[[:space:]]/, "", secao)
    if (secao == "[General]") tem_general = 1
    if (secao == "[Network]") tem_network = 1
    print
    next
}
{
    if (secao == "[General]" && $0 ~ /^[[:space:]]*EnableNetworkConfiguration[[:space:]]*=/) next
    if (secao == "[Network]" && $0 ~ /^[[:space:]]*(EnableIPv6|NameResolvingService)[[:space:]]*=/) next
    print
}
END {
    encerrar_secao()
    if (!tem_general) {
        print ""
        print "[General]"
        print "EnableNetworkConfiguration=true"
    }
    if (!tem_network) {
        print ""
        print "[Network]"
        print "EnableIPv6=true"
        print "NameResolvingService=none"
    }
}
' "$ORIGEM" > "$ARQUIVO_TEMP"
install -o root -g root -m 644 "$ARQUIVO_TEMP" "$IWD_CONF"
rm -f -- "$ARQUIVO_TEMP"
ARQUIVO_TEMP=''

## II. AdGuard DNS no systemd-resolved
### II.I. Usa apenas os endereços IPv4 dos servidores DNS (sem desativar IPv6 do sistema)
### II.II. TLS obrigatório por padrão, impedindo downgrade automático
printf '\n[4/6] Configurando o AdGuard DNS (DNS-over-TLS: %s)...\n' "$MODO_TLS"
install -d -m 755 /etc/systemd/resolved.conf.d
cat > "$RESOLVED_CONF" <<FIM
# Servidores públicos do AdGuard DNS com bloqueio de anúncios e rastreadores.
# DNS-over-TLS exige autenticação de dns.adguard-dns.com quando habilitado.
[Resolve]
DNS=${ADGUARD_1}#${ADGUARD_TLS} ${ADGUARD_2}#${ADGUARD_TLS}
Domains=~.
DNSOverTLS=${MODO_TLS}
FallbackDNS=
DNSStubListener=yes
FIM
chmod 644 "$RESOLVED_CONF"

## III. Serviço DNS local e integração com os aplicativos
### III.I. O endereço 127.0.0.53 será gerenciado pelo systemd-resolved
printf '\n[5/6] Ativando serviços e aplicando as alterações...\n'
systemctl enable --now systemd-resolved.service
ln -sfn /run/systemd/resolve/stub-resolv.conf "$RESOLV_CONF"
systemctl restart systemd-resolved.service
### III.II. Reinicia o iwd para reler o main.conf; o Wi-Fi pode cair brevemente
systemctl enable --now iwd.service
systemctl restart iwd.service

# =====================
# V. Verificação
# =====================
## I. Consulta de DNS sem usar entradas antigas em cache
### I.I. Dá alguns segundos para a interface Wi-Fi reconectar
printf '\n[6/6] Testando a resolução de nomes...\n'
resolvectl flush-caches || true
resolucao_ok=false
for tentativa in 1 2 3 4 5 6 7 8; do
    if resolvectl --cache=no --protocol=dns query debian.org >/dev/null 2>&1 && getent ahostsv4 debian.org >/dev/null 2>&1; then
        resolucao_ok=true
        break
    fi
    sleep 2
done

## II. Resultado e diagnóstico
### II.I. Mostra as configurações efetivas e o caminho do backup
printf '\nConfiguração efetiva do resolved:\n'
resolvectl status --no-pager || true
printf '\nArquivo /etc/resolv.conf:\n'
ls -l "$RESOLV_CONF"
printf '\nBackup: %s\n' "$BACKUP_DIR"
if [[ "$resolucao_ok" == true ]]; then
    printf '\nSUCESSO: resolução de nomes funcionando com o AdGuard configurado.\n'
    printf 'Verifique o bloqueio em: https://adguard.com/en/test.html\n'
else
    printf '\nATENÇÃO: não foi possível resolver debian.org.\n' >&2
    if [[ "$MODO_TLS" == yes ]]; then
        printf 'Verifique os registros do resolved e a conectividade DNS-over-TLS.\n' >&2
        printf 'Para testar o AdGuard sem TLS:\n' >&2
        printf '  sudo bash %s --sem-tls\n' "$0" >&2
    fi
    printf 'Diagnóstico: journalctl -u systemd-resolved -u iwd -n 60 --no-pager\n' >&2
    printf 'Para restaurar o backup desta execução:\n' >&2
    printf '  sudo bash %s --restaurar "%s"\n' "$0" "$BACKUP_DIR" >&2
    exit 2
fi
