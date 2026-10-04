#!/bin/bash

echo "=========================================================="
echo " Instalador e Adaptador do KDE Connect para SwayFX "
echo "=========================================================="

echo "[*] Instalando o KDE Connect e dependências essenciais..."
# wl-clipboard é vital para o sync de área de transferência funcionar no Sway (Wayland)
sudo apt-get update
sudo apt-get install -y kdeconnect wl-clipboard dbus-x11

echo "[*] Garantindo que os serviços comecem junto com o Sway..."
SWAY_CONFIG="$HOME/.config/sway/config"

# O Sway precisa ser instruído a lançar o indicador gráfico
if [ -f "$SWAY_CONFIG" ]; then
    if ! grep -q "kdeconnect-indicator" "$SWAY_CONFIG"; then
        echo "" >> "$SWAY_CONFIG"
        echo "# Autostart do KDE Connect" >> "$SWAY_CONFIG"
        echo "exec --no-startup-id /usr/bin/kdeconnect-indicator" >> "$SWAY_CONFIG"
        echo "[+] Regra de autostart adicionada ao $SWAY_CONFIG"
    else
        echo "[-] Regra de autostart já existe no Sway."
    fi
else
    echo "[!] Aviso: Arquivo de configuração do Sway não encontrado em $SWAY_CONFIG."
    echo "    Se você usar outro caminho, precisará adicionar 'exec --no-startup-id kdeconnect-indicator' manualmente."
fi

echo "[*] Configurando portas de Firewall (Se você usar UFW)..."
if [ -x /usr/sbin/ufw ] || [ -x /sbin/ufw ] || command -v ufw &> /dev/null; then
    echo "    Liberando portas TCP e UDP de 1714 a 1764..."
    sudo ufw allow 1714:1764/udp
    sudo ufw allow 1714:1764/tcp
    sudo ufw reload
    echo "[+] Firewall configurado!"
else
    echo "[-] UFW não detectado. Assumindo que as portas não estão bloqueadas localmente."
fi

echo "=========================================================="
echo "[+] Concluído! "
echo "Para iniciar agora sem reiniciar a sessão, rodando o indicador:"
nohup /usr/bin/kdeconnect-indicator >/dev/null 2>&1 &
echo "[+] Olhe a sua barra de tarefas, o ícone do KDE Connect deve aparecer em instantes."
echo "Agora é só parear com o aplicativo no seu celular no mesmo Wi-Fi!"
