#!/bin/sh
export BASE_DOMAIN=$(cat /run/secrets/BASE_DOMAIN)
exec traefik "$@"