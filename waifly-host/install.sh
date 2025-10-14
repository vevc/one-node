#!/usr/bin/env sh

XRAY_VERSION="${XRAY_VERSION:-25.9.11}"
HY2_VERSION="${HY2_VERSION:-2.6.4}"
ARGO_VERSION="${ARGO_VERSION:-2025.9.1}"
DOMAIN="${DOMAIN:-node.waifly.com}"
PORT="${PORT:-10008}"
UUID="${UUID:-2584b733-9095-4bec-a7d5-62b473540f7a}"
ARGO_DOMAIN="${ARGO_DOMAIN:-xxx.trycloudflare.com}"
ARGO_TOKEN="${ARGO_TOKEN:-}"

curl -sSL -o app.js https://raw.githubusercontent.com/vevc/one-node/refs/heads/dev/waifly-host/app.js
curl -sSL -o package.json https://raw.githubusercontent.com/vevc/one-node/refs/heads/dev/waifly-host/package.json

mkdir -p /home/container/cf
cd /home/container/cf
curl -sSL -o cf https://github.com/cloudflare/cloudflared/releases/download/$ARGO_VERSION/cloudflared-linux-amd64
chmod +x cf

mkdir -p /home/container/xy
cd /home/container/xy
curl -sSL -o Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/download/v$XRAY_VERSION/Xray-linux-64.zip
unzip Xray-linux-64.zip
rm Xray-linux-64.zip
mv xray xy
curl -sSL -o config.json https://raw.githubusercontent.com/vevc/one-node/refs/heads/dev/waifly-host/xray-config.json
sed -i "s/10008/$PORT/g" config.json
sed -i "s/YOUR_UUID/$UUID/g" config.json
keyPair=$(./xy x25519)
privateKey=$(echo "$keyPair" | grep "PrivateKey" | awk '{print $2}')
publicKey=$(echo "$keyPair" | grep "Password" | awk '{print $2}')
sed -i "s/YOUR_PRIVATE_KEY/$privateKey/g" config.json
shortId=$(openssl rand -hex 4)
sed -i "s/YOUR_SHORT_ID/$shortId/g" config.json
wsUrl="vless://$UUID@$ARGO_DOMAIN:443?encryption=none&security=tls&fp=chrome&type=ws&path=%2F%3Fed%3D2560#waifly-ws-argo"
echo $wsUrl > /home/container/node.txt
realityUrl="vless://$UUID@$DOMAIN:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=$publicKey&sid=$shortId&spx=%2F&type=tcp&headerType=none#waifly-reality"
echo $realityUrl >> /home/container/node.txt

mkdir -p /home/container/h2
cd /home/container/h2
curl -sSL -o h2 https://github.com/apernet/hysteria/releases/download/app%2Fv$HY2_VERSION/hysteria-linux-amd64
curl -sSL -o config.yaml https://raw.githubusercontent.com/vevc/one-node/refs/heads/dev/waifly-host/hysteria-config.yaml
openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout key.pem -out cert.pem -subj "/CN=$DOMAIN"
chmod +x h2
sed -i "s/10008/$PORT/g" config.yaml
sed -i "s/HY2_PASSWORD/$UUID/g" config.yaml
hy2Url="hysteria2://$UUID@$DOMAIN:$PORT?insecure=1#waifly-hy2"
echo $hy2Url >> /home/container/node.txt

cd /home/container
sed -i "s/node.waifly.com/$DOMAIN/g" app.js
sed -i "s/10008/$PORT/g" app.js
sed -i "s/YOUR_UUID/$UUID/g" app.js
sed -i "s/YOUR_SHORT_ID/$shortId/g" app.js
sed -i "s/YOUR_PUBLIC_KEY/$publicKey/g" app.js
sed -i "s/xxx.trycloudflare.com/$ARGO_DOMAIN/g" app.js
sed -i 's/ARGO_TOKEN = ""/ARGO_TOKEN = "'$ARGO_TOKEN'"/g' app.js

echo "============================================================"
echo "🚀 VLESS Reality & HY2 Node Info"
echo "------------------------------------------------------------"
echo "$wsUrl"
echo "$realityUrl"
echo "$hy2Url"
echo "============================================================"
