#!/bin/bash
set -e

WORKDIR="$HOME/wanzeller"
REPO="https://raw.githubusercontent.com/wwenderson/docker/main"

# 🗂️ Cria diretório de trabalho
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# 🔍 Verifica se o 'envsubst' está instalado
if ! command -v envsubst >/dev/null 2>&1; then
  echo "⚠️  O utilitário 'envsubst' não está instalado. Tentando instalar automaticamente..."
  if command -v apt >/dev/null 2>&1; then
    sudo apt update && sudo apt install -y gettext-base
  else
    echo "❌ Instalação automática falhou. Por favor, instale manualmente com:"
    echo "   sudo apt install gettext-base"
    exit 1
  fi
fi

# 1) Coleta os dados do usuário
while true; do
  read -p "Informe o nome de usuário base (ex: wanzeller): " USUARIO
  [[ "$USUARIO" =~ ^[a-zA-Z0-9_]{3,}$ ]] && break
  echo "❌ Nome de usuário inválido. Use apenas letras, números ou underline. Mínimo 3 caracteres."
done

while true; do
  read -p "Informe o e-mail principal do sistema (ex: voce@dominio.com): " EMAIL
  [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && break
  echo "❌ E-mail inválido. Exemplo: seuemail@dominio.com"
done

while true; do
  read -p "Informe o domínio principal (ex: seudominio.com): " DOMINIO
  [[ "$DOMINIO" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && break
  echo "❌ Domínio inválido. Exemplo: seudominio.com"
done

RADICAL=$(echo "$DOMINIO" | awk -F. '{print $(NF-1)}')

while true; do
  read -s -p "Defina uma senha segura (mínimo 8 caracteres): " SENHA
  echo
  read -s -p "Confirme a senha: " CONFIRMA
  echo
  if [[ "$SENHA" == "$CONFIRMA" && ${#SENHA} -ge 8 ]]; then
    break
  fi
  echo "❌ As senhas não coincidem ou são muito curtas. Tente novamente."
done

# 2) Criação de secrets individuais
for VARIAVEL in DOMINIO EMAIL USUARIO RADICAL SENHA; do
  VALOR="${!VARIAVEL}"
  if docker secret inspect "$VARIAVEL" >/dev/null 2>&1; then
    docker secret rm "$VARIAVEL" >/dev/null 2>&1 || true
  fi
  echo "$VALOR" | docker secret create "$VARIAVEL" -
  echo "✅ Secret '$VARIAVEL' criado."
done

# 3) Criação das redes necessárias
docker network create --driver=overlay --attachable traefik_public >/dev/null 2>&1 || true
docker network create --driver=overlay --attachable wanzeller_network >/dev/null 2>&1 || true

# 4) Carrega variáveis no ambiente para uso com envsubst
set -a
export DOMINIO EMAIL USUARIO RADICAL SENHA
set +a

# 5) Gera .env para uso manual ou no Portainer
cat > "$WORKDIR/.env" <<EOF
DOMAIN=$DOMINIO
EMAIL=$EMAIL
USUARIO=$USUARIO
RADICAL=$RADICAL
SENHA=$SENHA
EOF

echo "✅ Arquivo '.env' gerado em $WORKDIR para uso no Portainer."

# 6) Deploy do Traefik com substituição de variáveis
echo "🚀 Deploy Traefik..."
curl -sSL "$REPO/traefik/docker-compose.yaml" | envsubst > "$WORKDIR/traefik.yaml"
docker stack deploy --detach=true -c "$WORKDIR/traefik.yaml" traefik

# 7) Deploy do Portainer com substituição de variáveis
echo "🚀 Deploy Portainer..."
curl -sSL "$REPO/portainer/docker-compose.yaml" | envsubst > "$WORKDIR/portainer.yaml"
docker stack deploy --detach=true -c "$WORKDIR/portainer.yaml" portainer