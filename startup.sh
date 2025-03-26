#!/bin/bash
# filepath: /home/mavi/mavie/startup.sh

# Definir caminho do projeto
PROJECT_DIR="/home/mavi/mavie"  
cd $PROJECT_DIR || { echo "Falha ao acessar diretório $PROJECT_DIR"; exit 1; }

# Log com informações detalhadas
echo "===== INÍCIO DA EXECUÇÃO EM $(date) =====" > $PROJECT_DIR/startup.log
echo "Usuário: $(whoami)" >> $PROJECT_DIR/startup.log
echo "Diretório: $(pwd)" >> $PROJECT_DIR/startup.log
echo "Display: $DISPLAY" >> $PROJECT_DIR/startup.log

# Verificar ambiente gráfico
if [ -z "$DISPLAY" ]; then
    echo "AVISO: Variável DISPLAY não definida" >> $PROJECT_DIR/startup.log
    export DISPLAY=:0.0
fi

# Atualizar o código via git pull
echo "Atualizando repositório..." >> $PROJECT_DIR/startup.log
git pull >> $PROJECT_DIR/startup.log 2>&1 || echo "AVISO: Falha ao atualizar via git" >> $PROJECT_DIR/startup.log

# Verificar e ativar ambiente Python disponível
if [ -d "$PROJECT_DIR/env" ] && [ -f "$PROJECT_DIR/env/bin/activate" ]; then
    echo "Ativando ambiente virtual local ./env" >> $PROJECT_DIR/startup.log
    source $PROJECT_DIR/env/bin/activate || { echo "Falha ao ativar ambiente ./env" >> $PROJECT_DIR/startup.log; exit 1; }
else
    echo "Ambiente virtual não encontrado, usando Conda" >> $PROJECT_DIR/startup.log
    
    # Ativar Conda 
    source ~/miniconda3/bin/activate || { echo "Falha ao ativar Conda" >> $PROJECT_DIR/startup.log; exit 1; }
    echo "Conda ativado" >> $PROJECT_DIR/startup.log
    
    # Verificar/instalar pacotes necessários
    echo "Verificando pacotes necessários..." >> $PROJECT_DIR/startup.log
    pip install -r $PROJECT_DIR/requirements.txt >> $PROJECT_DIR/startup.log 2>&1 || echo "AVISO: Alguns pacotes podem não ter sido instalados corretamente" >> $PROJECT_DIR/startup.log
fi

# Forçar uso de TFLite para compatibilidade com ARM
export OWW_USE_TFLITE=1
echo "$(date) - Usando TFLite em vez de ONNX" >> $PROJECT_DIR/startup.log

# Iniciar servidor wake word sem flag de debug (removi -d)
echo "Iniciando servidor wake word..." >> $PROJECT_DIR/startup.log
python $PROJECT_DIR/wakeword_server.py > $PROJECT_DIR/wakeword.log 2>&1 &
WAKEWORD_PID=$!
echo "$(date) - Servidor wake word iniciado (PID: $WAKEWORD_PID)" >> $PROJECT_DIR/startup.log

# Verificar se o processo está rodando
sleep 2
if ! ps -p $WAKEWORD_PID > /dev/null; then
    echo "ERRO: Servidor wake word falhou ao iniciar" >> $PROJECT_DIR/startup.log
    cat $PROJECT_DIR/wakeword.log >> $PROJECT_DIR/startup.log
    exit 1
fi

# Abrir o navegador com a página HTML
echo "Abrindo página HTML no navegador..." >> $PROJECT_DIR/startup.log
if command -v chromium-browser &> /dev/null; then
    chromium-browser --start-fullscreen --no-sandbox $PROJECT_DIR/websocket_tester_ww.html &
elif command -v chromium &> /dev/null; then
    chromium --start-fullscreen --no-sandbox $PROJECT_DIR/websocket_tester_ww.html &
else
    echo "AVISO: Chromium não encontrado, tentando outros navegadores" >> $PROJECT_DIR/startup.log
    for browser in firefox epiphany-browser midori; do
        if command -v $browser &> /dev/null; then
            $browser $PROJECT_DIR/websocket_tester_ww.html &
            break
        fi
    done
fi
BROWSER_PID=$!
echo "$(date) - Navegador iniciado (PID: $BROWSER_PID)" >> $PROJECT_DIR/startup.log

# Manter o script rodando
wait $WAKEWORD_PID