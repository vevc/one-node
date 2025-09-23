#!/usr/bin/env sh

ARGO_TOKEN=

if [ -z "$ARGO_TOKEN" ]; then
  nohup $PWD/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 --url http://localhost:8090 1>$PWD/argo.log 2>&1 &
else
  nohup $PWD/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token $ARGO_TOKEN 1>$PWD/argo.log 2>&1 &
fi
