#!/bin/sh
# Ponto de entrada padrão para todos os containers com secrets

# Exporta variáveis de secrets
for VAR in DOMINIO EMAIL USUARIO RADICAL SENHA; do
  if [ -f "/run/secrets/$VAR" ]; then
    export "$VAR"="$(cat /run/secrets/$VAR)"
  fi
done

# Executa o comando original do container
exec "$@"