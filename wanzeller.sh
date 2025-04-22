#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/wwenderson/portainer/main"
WORKDIR="$HOME/wanzeller"
mkdir -p "$WORKDIR" && cd "$WORKDIR"

#
# 0 · dependência mínima
#
if ! command -v envsubst >/dev/null; then
  echo "Instalando gettext-base (envsubst)…"
  sudo apt-get update -qq && sudo apt-get install -y -qq gettext-base
fi

#
# 1 · inputs do usuário
#
read -rp "Usuário base           : " USUARIO
while [[ ! $USUARIO =~ ^[A-Za-z0-9_]{3,}$ ]]; do
  read -rp "❌ Inválido. Tente de novo: " USUARIO
done

read -rp "E‑mail administrativo  : " EMAIL
while [[ ! $EMAIL =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; do
  read -rp "❌ Inválido. Tente de novo: " EMAIL
done

read -rp "Domínio principal      : " DOMINIO
while [[ ! $DOMINIO =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; do
  read -rp "❌ Inválido. Tente de novo: " DOMINIO
done

RADICAL=$(awk -F. '{print $(NF-1)}' <<<"$DOMINIO")

while :; do
  read -srp "Senha (≥8)             : " SENHA; echo
  read -srp "Confirmar senha        : " CONF; echo
  [[ $SENHA == "$CONF" && ${#SENHA} -ge 8 ]] && break
  echo "❌ Senha curta ou não confere."
done

#
# 2 · secrets
#
for VAR in DOMINIO EMAIL USUARIO RADICAL SENHA; do
  docker secret rm "$VAR" >/dev/null 2>&1 || true
  printf '%s\n' "${!VAR}" | docker secret create "$VAR" -
done
echo "✅ Secrets atualizados."

#
# 3 · rede + volume para certificados
#
docker network create --driver=overlay --attachable traefik_public 2>/dev/null || true
docker network create --driver=overlay --attachable wanzeller_network 2>/dev/null || true
docker volume  create traefik_certificates                          2>/dev/null || true

#
# 4 · exporta para o envsubst (vidas curtíssima — só neste shell)
#
export DOMINIO EMAIL USUARIO RADICAL SENHA
set -a   # inclui variáveis novas no ambiente
set +a

#
# 5 · deploy
#
# Traefik
curl -fsSL "$REPO_RAW/traefik.yaml" \
  | envsubst '$EMAIL $DOMINIO' \
  | docker stack deploy -c - traefik  

# Portainer
curl -fsSL "$REPO_RAW/portainer.yaml" \
  | envsubst '$DOMINIO' \
  | docker stack deploy -c - portainer

echo "✨ Pronto!  Consulte https://traefik.$DOMINIO e https://portainer.$DOMINIO"