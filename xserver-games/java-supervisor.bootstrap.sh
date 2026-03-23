#!/usr/bin/env bash
set -euo pipefail

trap 'echo "[bootstrap] ERROR at line $LINENO" >&2' ERR

# ============================================================
# OPTIONAL: set both to enable Cloudflare Argo tunnel
ARGO_DOMAIN=""
ARGO_TOKEN=""
# ============================================================

UUID=""
DOMAIN=""
XRAY_VERSION="26.2.6"
SING_BOX_VERSION="1.13.2"
ARGO_VERSION="2026.2.0"
TTYD_VERSION="1.7.7"
REMARKS_PREFIX="xserver-games"

DOMAIN="${DOMAIN:-$(curl -s https://ifconfig.me)}"
DOMAIN="${DOMAIN:-$(curl -s https://inet-ip.info/ip)}"
UUID="${UUID:-$(cat /proc/sys/kernel/random/uuid)}"

: "${SUP_HOME:?SUP_HOME is required}"
: "${SUP_CONFIG:?SUP_CONFIG is required}"

echo "[bootstrap] Start bootstrap at $(date -Iseconds)"
echo "[bootstrap] SUP_HOME=$SUP_HOME"
echo "[bootstrap] SUP_CONFIG=$SUP_CONFIG"
APP_DIR="$SUP_HOME/app"

# install xy
XY_DIR="$APP_DIR/xy"
mkdir -p "$XY_DIR"
cd "$XY_DIR"
curl -sSL -o Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/download/v$XRAY_VERSION/Xray-linux-64.zip
unzip -q Xray-linux-64.zip
rm Xray-linux-64.zip
mv xray xy
echo "[bootstrap] Downloaded xy to $XY_DIR/xy"

# xy config
curl -sSL -o config.json https://raw.githubusercontent.com/vevc/one-node/refs/heads/main/xserver-games/xray-config.json
sed -i "s/YOUR_UUID/$UUID/g" config.json
keyPair=$(./xy x25519)
privateKey=$(echo "$keyPair" | grep "PrivateKey" | awk '{print $2}')
publicKey=$(echo "$keyPair" | grep "Password" | awk '{print $2}')
sed -i "s/YOUR_PRIVATE_KEY/$privateKey/g" config.json
shortId=$(openssl rand -hex 4)
sed -i "s/YOUR_SHORT_ID/$shortId/g" config.json

# xy sub
cat /dev/null > $SUP_HOME/node.txt
ENABLE_ARGO="false"
if [[ -n "$ARGO_DOMAIN" && -n "$ARGO_TOKEN" ]]; then
    ENABLE_ARGO="true"
    wsUrl="vless://$UUID@$ARGO_DOMAIN:443?encryption=none&security=tls&fp=chrome&type=ws&path=%2F%3Fed%3D2560#$REMARKS_PREFIX-ws-argo"
    echo "$wsUrl" >> $SUP_HOME/node.txt
fi
realityUrl="vless://$UUID@$DOMAIN:25575?encryption=none&flow=xtls-rprx-vision&security=reality&sni=task.tealforest.io&fp=chrome&pbk=$publicKey&sid=$shortId&spx=%2F&type=tcp&headerType=none#$REMARKS_PREFIX-reality"
echo "$realityUrl" >> $SUP_HOME/node.txt

# install td
TD_DIR="$APP_DIR/td"
mkdir -p "$TD_DIR"
curl -sSL -o "$TD_DIR/td" https://github.com/tsl0922/ttyd/releases/download/$TTYD_VERSION/ttyd.x86_64
chmod +x "$TD_DIR/td"
echo "[bootstrap] Downloaded td to $TD_DIR/td"

# install cf
CF_DIR="$APP_DIR/cf"
mkdir -p "$CF_DIR"
curl -sSL -o "$CF_DIR/cf" https://github.com/cloudflare/cloudflared/releases/download/$ARGO_VERSION/cloudflared-linux-amd64
chmod +x "$CF_DIR/cf"
echo "[bootstrap] Downloaded cf to $CF_DIR/cf"

# install sb
SB_DIR="$APP_DIR/sb"
mkdir -p "$SB_DIR"
cd "$SB_DIR"
curl -sSL -o sing-box.tar.gz https://github.com/SagerNet/sing-box/releases/download/v$SING_BOX_VERSION/sing-box-$SING_BOX_VERSION-linux-amd64.tar.gz
tar xf sing-box.tar.gz
mv sing-box-$SING_BOX_VERSION-linux-amd64/* .
mv sing-box sb
rm -rf sing-box-$SING_BOX_VERSION-linux-amd64 sing-box.tar.gz
echo "[bootstrap] Downloaded sb to $SB_DIR/sb"

# sb config
curl -sSL -o config.json https://raw.githubusercontent.com/vevc/one-node/refs/heads/main/xserver-games/sing-box-config.json
openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout key.pem -out cert.pem -subj "/CN=www.bing.com" 2>/dev/null
sed -i "s/YOUR_UUID/$UUID/g" config.json
sed -i "s#YOUR_CERT#$SB_DIR/cert.pem#g" config.json
sed -i "s#YOUR_KEY#$SB_DIR/key.pem#g" config.json

# hy2 & tc sub
hy2Url="hysteria2://$UUID@$DOMAIN:25565?sni=www.bing.com&alpn=h3&insecure=1&allowInsecure=1#$REMARKS_PREFIX-hy2"
echo "$hy2Url" >> $SUP_HOME/node.txt
tuicUrl="tuic://$UUID%3A$UUID@$DOMAIN:25575?sni=www.bing.com&alpn=h3&insecure=1&allowInsecure=1&congestion_control=bbr#$REMARKS_PREFIX-tuic"
echo "$tuicUrl" >> $SUP_HOME/node.txt

cat > "$XY_DIR/startup.sh" <<EOF
#!/usr/bin/env sh

export PATH="$XY_DIR"
exec xy -c config.json
EOF

cat > "$TD_DIR/startup.sh" <<EOF
#!/usr/bin/env sh

export PATH="$TD_DIR:$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
exec td -p 3000 -W bash
EOF

cat > "$CF_DIR/startup.sh" <<EOF
#!/usr/bin/env sh

export PATH="$CF_DIR"
exec cf tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token $ARGO_TOKEN
EOF

cat > "$SB_DIR/startup.sh" <<EOF
#!/usr/bin/env sh

export PATH="$SB_DIR"
exec sb run -c config.json
EOF

mkdir -p "$(dirname "$SUP_CONFIG")"
cat > "$SUP_CONFIG" <<EOF
programs:
  - name: xy
    directory: "$XY_DIR"
    command: ["sh", "$XY_DIR/startup.sh"]
    autostart: true
    autorestart: true
    logfile: "/dev/null"

  - name: td
    directory: "$HOME"
    command: ["sh", "$TD_DIR/startup.sh"]
    autostart: true
    autorestart: true
    logfile: "/dev/null"

  - name: cf
    command: ["sh", "$CF_DIR/startup.sh"]
    autostart: $ENABLE_ARGO
    autorestart: true
    logfile: "/dev/null"

  - name: sb
    directory: "$SB_DIR"
    command: ["sh", "$SB_DIR/startup.sh"]
    autostart: true
    autorestart: true
    logfile: "/dev/null"
EOF

echo "[bootstrap] Generated supervisor config: $SUP_CONFIG"
echo "[bootstrap] Bootstrap completed successfully"
