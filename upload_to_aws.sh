#!/bin/bash

# Cores para feedback visual
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Verificando arquivo de chave...${NC}"

# Verificar se o arquivo .pem está acessível
if [ ! -f "mavi-api-server.pem" ]; then
    echo -e "${RED}Erro: Arquivo mavi-api-server.pem não encontrado.${NC}"
    exit 1
fi

# Corrigir permissões da chave
chmod 400 mavi-api-server.pem
echo -e "${GREEN}Permissões da chave ajustadas.${NC}"

# Definir servidor e diretório de destino
SERVER="ubuntu@100.26.31.165"
DEST_DIR="/home/ubuntu/mavie"  # Caminho completo e correto

# Verificar se o diretório de destino existe, caso contrário, criá-lo
echo -e "${YELLOW}Verificando diretório de destino...${NC}"
ssh -i mavi-api-server.pem $SERVER "mkdir -p $DEST_DIR"

# Listar o que será transferido (modo de simulação)
echo -e "${YELLOW}Arquivos que serão transferidos (simulação):${NC}"
rsync -avzn --exclude=".git/" --exclude="env/" --exclude="venv/" \
      --exclude="*.onnx" --exclude="*.pth" --exclude="*.pb" --exclude="*.h5" \
      --exclude="*.pem" --exclude="__pycache__/" --exclude="*.pyc" \
      --exclude=".env" --exclude=".idea/" --exclude=".vscode/" \
      --exclude="*.log" --exclude="logs/" \
      -e "ssh -i mavi-api-server.pem" ./ $SERVER:$DEST_DIR

# Verificar resultado
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Transferência concluída com sucesso!${NC}"
else
    echo -e "${RED}Erro durante a transferência!${NC}"
    exit 1
fi

echo -e "${YELLOW}Listando arquivos no servidor:${NC}"
ssh -i mavi-api-server.pem $SERVER "ls -la $DEST_DIR"