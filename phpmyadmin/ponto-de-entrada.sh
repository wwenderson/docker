#!/bin/sh
for V in DOMINIO EMAIL USUARIO RADICAL SENHA; do
  [ -f "/run/secrets/$V" ] && export "$V=$(cat /run/secrets/$V)"
done
exec "$@"