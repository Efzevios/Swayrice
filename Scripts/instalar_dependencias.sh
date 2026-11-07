#!/usr/bin/env bash
set -euo pipefail

uso() {
    cat <<'EOF'
Instalador de dependências do TRADUZIR (Debian 13)
Uso: bash instalar_dependencias.sh [opções]
  --basico    Bash, Python, GNU coreutils e utilitários
  --apis      pipx, llm e plugins OpenRouter/Gemini/Anthropic
  --shell     translate-shell (trans)
  --apertium  motor Apertium e pares EN↔ES, ES↔PT
  --argos     Argos Translate (pipx; modelo de idioma à parte)
  --man       man-db e páginas em português
  --tudo      todas as opções acima
  --ajuda     esta ajuda
Sem opções, exibe esta ajuda; nada é instalado automaticamente.
EOF
}

if (( $# == 0 )); then uso; exit 0; fi
basico=0 apis=0 shell=0 apertium=0 argos=0 man=0
for opt in "$@"; do
    case "$opt" in
        --basico) basico=1 ;;
        --apis) apis=1 ;;
        --shell) shell=1 ;;
        --apertium) apertium=1 ;;
        --argos) argos=1 ;;
        --man) man=1 ;;
        --tudo) basico=1; apis=1; shell=1; apertium=1; argos=1; man=1 ;;
        --ajuda|-h|--help) uso; exit 0 ;;
        *) printf 'Opção inválida: %s\n' "$opt" >&2; uso >&2; exit 2 ;;
    esac
done
if ! command -v apt-get >/dev/null 2>&1; then
    printf 'Este instalador foi preparado para Debian/Ubuntu com apt-get.\n' >&2
    exit 2
fi

pacotes=()
if (( basico )); then
    pacotes+=(bash python3 coreutils grep sed gawk findutils locales ca-certificates)
fi
if (( apis || argos )); then
    pacotes+=(pipx python3-venv)
fi
if (( shell )); then pacotes+=(translate-shell); fi
if (( apertium )); then pacotes+=(apertium apertium-eng-spa apertium-es-pt); fi
if (( man )); then pacotes+=(man-db manpages-pt-br manpages-pt-br-dev); fi
if (( ${#pacotes[@]} )); then
    printf 'Instalando pacotes do sistema via apt...\n'
    sudo apt-get update
    sudo apt-get install -y "${pacotes[@]}"
fi

export PATH="$HOME/.local/bin:$PATH"
if (( apis || argos )); then
    pipx ensurepath
fi
if (( apis )); then
    if ! pipx list --short 2>/dev/null | grep -Eq '^llm([[:space:]]|$)'; then
        pipx install llm
    fi
    pipx inject llm llm-openrouter llm-gemini llm-anthropic
    printf '\nAPIs instaladas. Cadastre sua chave separadamente com: llm keys set openrouter\n'
fi
if (( argos )); then
    if ! pipx list --short 2>/dev/null | grep -Eq '^argostranslate([[:space:]]|$)'; then
        pipx install argostranslate
    fi
    printf '\nArgos instalado. Instale o modelo de idioma depois de consultar:\n'
    printf '  argospm update\n  argospm search --from-lang en --to-lang pb\n'
    printf '  argospm install translate-en_pb   (se disponível)\n'
fi
if (( apertium )); then
    printf '\nConfira os modos Apertium: apertium -l\n'
fi
if (( man )); then
    printf '\nSe necessário, gere pt_BR.UTF-8: sudo dpkg-reconfigure locales\n'
fi
printf '\nInstalação concluída. Consulte DEPENDENCIAS.md para configurar cada mecanismo.\n'
