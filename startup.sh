#!/bin/bash
# filepath: /home/mavi/mavie/startup.sh

# Definir caminho do projeto
PROJECT_DIR="/home/mavi/mavie"  
cd $PROJECT_DIR || { echo "Falha ao acessar diretório $PROJECT_DIR"; exit 1; }

# Melhorar log com informações mais detalhadas
echo "===== INÍCIO DA EXECUÇÃO EM $(date) =====" > $PROJECT_DIR/startup.log
echo "Usuário: $(whoami)" >> $PROJECT_DIR/startup.log
echo "Diretório: $(pwd)" >> $PROJECT_DIR/startup.log
echo "Display: $DISPLAY" >> $PROJECT_DIR/startup.log

# Verificar se o ambiente gráfico está disponível
if [ -z "$DISPLAY" ]; then
    echo "AVISO: Variável DISPLAY não definida" >> $PROJECT_DIR/startup.log
    export DISPLAY=:0.0
fi

# Verificar o Conda antes de tentar ativá-lo
if [ ! -f ~/miniconda3/bin/activate ]; then
    echo "ERRO: Arquivo de ativação do Conda não encontrado" >> $PROJECT_DIR/startup.log
    exit 1
fi

# Ativar ambiente Conda
source ~/miniconda3/bin/activate
conda activate base || { echo "Falha ao ativar ambiente Conda" >> $PROJECT_DIR/startup.log; exit 1; }
echo "$(date) - Conda ativado" >> $PROJECT_DIR/startup.log

# Forçar uso de TFLite para evitar erro de instrução ilegal
export OWW_USE_TFLITE=1
echo "$(date) - Usando TFLite em vez de ONNX" >> $PROJECT_DIR/startup.log

# Verificar se o script Python existe
if [ ! -f "$PROJECT_DIR/wakeword_server.py" ]; then
    echo "ERRO: Arquivo wakeword_server.py não encontrado" >> $PROJECT_DIR/startup.log
    exit 1
fi

# Iniciar servidor wake word em segundo plano
python "$PROJECT_DIR/wakeword_server.py" > $PROJECT_DIR/wakeword.log 2>&1 &
WAKEWORD_PID=$!
echo "$(date) - Servidor wake word iniciado (PID: $WAKEWORD_PID)" >> $PROJECT_DIR/startup.log

# Verificar se o processo está rodando
sleep 2
if ! ps -p $WAKEWORD_PID > /dev/null; then
    echo "ERRO: Servidor wake word falhou ao iniciar" >> $PROJECT_DIR/startup.log
    # Mostrar erros
    cat $PROJECT_DIR/wakeword.log >> $PROJECT_DIR/startup.log
    exit 1
fi

# Verificar se o navegador está instalado
if ! command -v chromium-browser &> /dev/null; then
    echo "ERRO: Chromium não encontrado, tentando alternativas..." >> $PROJECT_DIR/startup.log
    BROWSER=$(command -v chromium || command -v firefox || command -v epiphany-browser)
    if [ -z "$BROWSER" ]; then
        echo "ERRO: Nenhum navegador encontrado" >> $PROJECT_DIR/startup.log
        exit 1
    fi
else
    BROWSER="chromium-browser"
fi

# Abrir o navegador com a página HTML
$BROWSER --start-fullscreen --no-sandbox $PROJECT_DIR/websocket_tester_ww.html &
BROWSER_PID=$!
echo "$(date) - Navegador iniciado (PID: $BROWSER_PID)" >> $PROJECT_DIR/startup.log

# Manter o script rodando
wait $WAKEWORD_PID