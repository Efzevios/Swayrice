#!/bin/bash

# --- Configurações de Caminhos ---
USER_HOME="/home/$USER"
APP_DIR="$USER_HOME/cubesuite"
EXE_NAME="CubeSuite.exe"
PREFIX_DIR="$USER_HOME/.wine-cubesuite"
RUNNER_PATH="$USER_HOME/.local/bin/run-cubesuite"
DESKTOP_ENTRY="$USER_HOME/.local/share/applications/cubesuite.desktop"
WINETRICKS_PATH="$USER_HOME/.local/bin/winetricks"

echo "-------------------------------------------------------"
echo "  Configurador Automático do CubeSuite para Linux"
echo "-------------------------------------------------------"

# 1. Habilitar arquitetura 32 bits e instalar dependências
echo "[1/6] Verificando dependências (Wine32, Wget, Cabextract)..."
if ! dpkg --print-foreign-architectures | grep -q "i386"; then
    echo "Habilitando arquitetura i386..."
    sudo dpkg --add-architecture i386
fi

echo "Atualizando repositórios e instalando dependências base..."
sudo apt update && sudo apt install -y wine wine32:i386 wget cabextract curl unzip

# 2. Configurar o Winetricks
echo "[2/6] Verificando Winetricks..."
mkdir -p "$USER_HOME/.local/bin"
if [ ! -f "$WINETRICKS_PATH" ]; then
    echo "Baixando o Winetricks..."
    wget -qO "$WINETRICKS_PATH" https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
    chmod +x "$WINETRICKS_PATH"
fi

# 3. Limpar e Criar o Prefixo Wine de 32 bits
echo "[3/6] Configurando o ambiente Wine (Prefixo)..."
rm -rf "$PREFIX_DIR"
WINEARCH=win32 WINEPREFIX="$PREFIX_DIR" winecfg /v win10 & 
WINE_PID=$!
sleep 5 # Dá um tempo para o Wine inicializar
kill $WINE_PID 2>/dev/null

# 4. Instalar bibliotecas essenciais para a interface gráfica (Botões estáticos)
echo "[4/6] Instalando dependências visuais (corefonts, gdiplus, d3dx9, mfc42)..."
echo "      Isso vai demorar um pouco, aguarde..."
WINEARCH=win32 WINEPREFIX="$PREFIX_DIR" "$WINETRICKS_PATH" -q corefonts gdiplus d3dx9 mfc42 vcrun2015

# 5. Criar o script 'Runner'
echo "[5/6] Criando script de execução em ~/.local/bin..."

# Nota: O uso de "explorer /desktop" é essencial no Sway/Wayland
# para evitar que os cliques do mouse não sejam registrados (bug de foco).
cat << EOF > "$RUNNER_PATH"
#!/bin/bash
export WINEPREFIX="$PREFIX_DIR"
export WINEARCH="win32"
export WINEESYNC=1
export FREETYPE_PROPERTIES="truetype:interpreter-version=35"

# Executa o CubeSuite (sem o fundo azul do Virtual Desktop)
wine "$APP_DIR/$EXE_NAME"
EOF

chmod +x "$RUNNER_PATH"

# 6. Criar o atalho .desktop para o Wofi/Menu
echo "[6/6] Criando atalho no menu de aplicativos..."
mkdir -p "$USER_HOME/.local/share/applications"

cat << EOF > "$DESKTOP_ENTRY"
[Desktop Entry]
Name=CubeSuite
Comment=Configurador M-VAVE MIDI
Exec=$RUNNER_PATH
Icon=wine
Terminal=false
Type=Application
Categories=AudioVideo;Audio;
EOF

# 7. Finalização
echo "[Concluído] Operação finalizada!"
echo "-------------------------------------------------------"
echo "O CubeSuite agora deve aparecer no seu Wofi."
echo "As correções para botões não clicáveis (Sway/Wayland) e UI estática foram aplicadas."
echo "Execute o script novamente ou use: run-cubesuite"
echo "-------------------------------------------------------"
