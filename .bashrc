# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    #alias grep='grep --color=auto'
    #alias fgrep='fgrep --color=auto'
    #alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
#alias ll='ls -l'
#alias la='ls -A'
#alias l='ls -CF'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# =====================
# Pessoal
# =====================
### I. Localização/língua
export LANG=pt_BR.UTF-8
export LANGUAGE=pt_BR:pt
## II. GTK
### II.I. Define o tema GTK e acento para aplicações (incluindo sandboxed)
export GTK_THEME="Colloid-Dark-Gruvbox"
export GTK2_RC_FILES="$HOME/.themes/Colloid-Dark-Gruvbox/gtk-2.0/gtkrc"
### II.II. Garante a existência dos links do Libadwaita na abertura do shell
if [ ! -f "$HOME/.config/gtk-3.0/gtk.css" ] && [ -f "$HOME/.config/gtk-4.0/gtk.css" ]; then
    mkdir -p ~/.config/gtk-3.0
    ln -sf ~/.config/gtk-4.0/gtk.css ~/.config/gtk-3.0/gtk.css
fi
### III. QT - Funcionamento
export QT_QPA_PLATFORM="wayland;xcb"
. "$HOME/.cargo/env"
### IV. LLM - Tradução
# Função de tradução técnica para o terminal usando llm
traduzir() {
    # 1. Lista de chaves do Gemini (adicione quantas quiser)
    local keys=(
        "CHAVE1"
        "CHAVE2"
        "CHAVE3"
        "CHAVE4"
        "CHAVE5"
    )

    # 2. Sorteia uma chave a cada execução para balancear os limites de requisição
    local selected_key=${keys[$RANDOM % ${#keys[@]}]}

    # 3. Prompt do sistema otimizado para comandos de terminal
    local system_prompt="Você é um tradutor especializado em GNU/Linux. Traduza o texto a seguir mantendo termos técnicos e formatação intactos."

    # 4. Captura o comando que foi executado antes do pipe (|)
    local raw_cmd
    raw_cmd=$(fc -ln -1 2>/dev/null | awk -F'|' '{print $1}' | xargs)

    # Fallback caso o histórico não capture a linha
    if [[ -z "$raw_cmd" ]]; then
        raw_cmd="comando_terminal"
    fi

    # Substitui caracteres especiais e espaços por underscores para evitar nomes inválidos
    local clean_cmd
    clean_cmd=$(echo "$raw_cmd" | tr -c 'a-zA-Z0-9._-' '_' | tr -s '_')

    # Define a pasta onde os arquivos serão salvos e insere um timestamp para não sobrescrever execuções anteriores
    local log_dir="$HOME/traduções"
    mkdir -p "$log_dir"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="${log_dir}/${clean_cmd}_${timestamp}.txt"

    # 5. Executa o llm e armazena a saída
    local output
    if output=$(GEMINI_API_KEY="$selected_key" llm -m gemini-3.5-flash -o temperature 0 -s "$system_prompt"); then
        # Exibe o resultado no terminal
        printf "%s\n" "$output"
        
        # Salva o resultado no arquivo
        printf "%s\n" "$output" > "$filename"
        echo -e "\n\033[0;32m[Salvo em: $filename]\033[0m" >&2
    else
        echo -e "\033[0;31m[Erro] Falha na tradução. Nenhum arquivo foi salvo.\033[0m" >&2
        return 1
    fi
}
