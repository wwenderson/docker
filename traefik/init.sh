#!/bin/sh
export DOMINIO=$(cat /run/secrets/DOMINIO)
exec traefik "$@"