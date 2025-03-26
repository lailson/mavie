#!/bin/bash
# filepath: /home/ubuntu/mavie/startup.sh

# Definir caminho do projeto
PROJECT_DIR="/home/ubuntu/mavie"
cd $PROJECT_DIR

# Iniciar log
echo "$(date) - Iniciando script de inicialização" > $PROJECT_DIR/startup.log

# Ativar ambiente Conda
source ~/miniconda3/bin/activate
conda activate base
echo "$(date) - Conda ativado" >> $PROJECT_DIR/startup.log

# Iniciar servidor wake word em segundo plano
python wakeword_server.py > $PROJECT_DIR/wakeword.log 2>&1 &
WAKEWORD_PID=$!
echo "$(date) - Servidor wake word iniciado (PID: $WAKEWORD_PID)" >> $PROJECT_DIR/startup.log

# Permitir que o servidor inicialize
sleep 3

# Abrir o navegador com a página HTML
chromium-browser --start-fullscreen --no-sandbox $PROJECT_DIR/websocket_tester_ww.html &
BROWSER_PID=$!
echo "$(date) - Navegador iniciado (PID: $BROWSER_PID)" >> $PROJECT_DIR/startup.log

# Manter o script rodando
wait $WAKEWORD_PID