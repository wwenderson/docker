#!/usr/bin/env bash
set -euo pipefail           # aborta em erro / variável não‑setada / pipe quebrado

REPO_RAW="https://raw.githubusercontent.com/wwenderson/portainer/main"
WORKDIR="$HOME/wanzeller"
mkdir -p "$WORKDIR" && cd "$WORKDIR"

#
# 0 · dependência mínima ────────────────
#
if ! command -v envsubst &>/dev/null; then
  echo "Instalando «gettext‑base» (envsubst)…"
  if command -v apt &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq gettext-base
  else
    echo "❌ Impossível instalar automaticamente. Instale «gettext-base» manualmente."
    exit 1
  fi
fi

#
# 1 · entrada do usuário ────────────────
#
read -rp "Usuário base               : " USUARIO
while [[ ! $USUARIO =~ ^[A-Za-z0-9_]{3,}$ ]]; do
  read -rp "❌ Inválido – só letras/números/_ (≥3). Tente de novo: " USUARIO
done

read -rp "E‑mail administrativo      : " EMAIL
while [[ ! $EMAIL =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; do
  read -rp "❌ Formato de e‑mail inválido. Tente de novo: " EMAIL
done

read -rp "Domínio principal          : " DOMINIO
while [[ ! $DOMINIO =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; do
  read -rp "❌ Domínio inválido (ex. seudominio.com). Tente: " DOMINIO
done

RADICAL=$(awk -F. '{print $(NF-1)}' <<<"$DOMINIO")

while :; do
  read -srp "Senha (mín. 8 caracteres) : " SENHA; echo
  read -srp "Confirme a senha          : " CONF;  echo
  [[ $SENHA == "$CONF" && ${#SENHA} -ge 8 ]] && break
  echo "❌ Senha curta ou não confere."
done

#
# 2 · secrets individuais ───────────────
#
for VAR in DOMINIO EMAIL USUARIO RADICAL SENHA; do
  docker secret rm "$VAR" &>/dev/null || true         # recria se já existir
  printf '%s\n' "${!VAR}" | docker secret create "$VAR" -
done
echo "✅ Secrets Docker criados/atualizados."

#
# 3 · redes + volume para certificados ──
#
docker network create --driver=overlay --attachable traefik_public    &>/dev/null || true
docker network create --driver=overlay --attachable wanzeller_network &>/dev/null || true

#
# 4 · exporta variáveis p/ envsubst ────
#
export DOMINIO EMAIL USUARIO RADICAL SENHA
set -a ; set +a                      # (garante que continuem no ambiente)

#
# 5 · opcional: arquivo .env p/ Portainer
#
cat > .env <<EOF
DOMINIO=$DOMINIO
EMAIL=$EMAIL
USUARIO=$USUARIO
RADICAL=$RADICAL
SENHA=$SENHA
EOF
echo "✅ «$WORKDIR/.env» gerado — pode ser anexado na GUI do Portainer."

#
# 6 · deploy das stacks ────────────────
#
echo "🚀 Traefik…"
curl -fsSL "$REPO_RAW/traefik.yaml"  \
  | envsubst '$EMAIL $DOMINIO'       \
  | docker stack deploy -c - traefik

echo "🚀 Portainer…"
curl -fsSL "$REPO_RAW/portainer.yaml" \
  | envsubst '$DOMINIO'               \
  | docker stack deploy -c - portainer

echo -e "\n✨ Tudo pronto!  Acesse:\n  https://traefik.$DOMINIO\n  https://portainer.$DOMINIO"