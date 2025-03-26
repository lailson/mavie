#!/bin/bash
# filepath: /home/ubuntu/mavie/startup.sh

# Definir caminho do projeto
PROJECT_DIR="/home/ubuntu/mavie"
cd $PROJECT_DIR

# Iniciar log
echo "$(date) - Iniciando script de inicialização" > $PROJECT_DIR/startup.log

# Executar git pull para atualizar o código
echo "$(date) - Verificando atualizações do repositório..." >> $PROJECT_DIR/startup.log
git pull >> $PROJECT_DIR/startup.log 2>&1

# Verificar se o git pull foi bem-sucedido
if [ $? -eq 0 ]; then
    echo "$(date) - Repositório atualizado com sucesso." >> $PROJECT_DIR/startup.log
else
    echo "$(date) - AVISO: Falha ao atualizar o repositório." >> $PROJECT_DIR/startup.log
    # Continua mesmo se falhar, usando a versão atual do código
fi

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