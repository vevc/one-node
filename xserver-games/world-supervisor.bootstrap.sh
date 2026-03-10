#!/usr/bin/env bash
set -euo pipefail

trap 'echo "[bootstrap] ERROR at line $LINENO" >&2' ERR

# ============================================================
# NOTE: configure values before use
ARGO_DOMAIN=""
ARGO_TOKEN=""
# ============================================================

DOMAIN=""
DOMAIN="${DOMAIN:-$(curl -s https://ifconfig.me)}"
DOMAIN="${DOMAIN:-$(curl -s https://inet-ip.info/ip)}"
UUID="${UUID:-$(cat /proc/sys/kernel/random/uuid)}"
XRAY_VERSION="${XRAY_VERSION:-26.2.6}"
SING_BOX_VERSION="${SING_BOX_VERSION:-1.13.2}"
ARGO_VERSION="${ARGO_VERSION:-2026.2.0}"
REMARKS_PREFIX="${REMARKS_PREFIX:-xserver-games}"

: "${WS_PROCESS_CWD:?WS_PROCESS_CWD is required}"
: "${WS_PLUGIN_DIR:?WS_PLUGIN_DIR is required}"
: "${WS_CONFIG_PATH:?WS_CONFIG_PATH is required}"

echo "[bootstrap] Start bootstrap at $(date -Iseconds)"
echo "[bootstrap] WS_PROCESS_CWD=$WS_PROCESS_CWD"
echo "[bootstrap] WS_PLUGIN_DIR=$WS_PLUGIN_DIR"
echo "[bootstrap] WS_CONFIG_PATH=$WS_CONFIG_PATH"

# install xy
XY_DIR="$WS_PLUGIN_DIR/xy"
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
wsUrl="vless://$UUID@$ARGO_DOMAIN:443?encryption=none&security=tls&fp=chrome&type=ws&path=%2F%3Fed%3D2560#$REMARKS_PREFIX-ws-argo"
echo $wsUrl > $WS_PLUGIN_DIR/node.txt
realityUrl="vless://$UUID@$DOMAIN:25575?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=$publicKey&sid=$shortId&spx=%2F&type=tcp&headerType=none#$REMARKS_PREFIX-reality"
echo $realityUrl >> $WS_PLUGIN_DIR/node.txt

# install td
TD_DIR="$WS_PLUGIN_DIR/td"
mkdir -p "$TD_DIR"
curl -sSL -o "$TD_DIR/td" https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64
chmod +x "$TD_DIR/td"
echo "[bootstrap] Downloaded td to $TD_DIR/td"

# install cf
CF_DIR="$WS_PLUGIN_DIR/cf"
mkdir -p "$CF_DIR"
curl -sSL -o "$CF_DIR/cf" https://github.com/cloudflare/cloudflared/releases/download/$ARGO_VERSION/cloudflared-linux-amd64
chmod +x "$CF_DIR/cf"
echo "[bootstrap] Downloaded cf to $CF_DIR/cf"

# install sb
SB_DIR="$WS_PLUGIN_DIR/sb"
mkdir -p "$SB_DIR"
cd "$SB_DIR"
curl -sSL -o sing-box.tar.gz https://github.com/SagerNet/sing-box/releases/download/v$SING_BOX_VERSION/sing-box-$SING_BOX_VERSION-linux-amd64.tar.gz
tar xf sing-box.tar.gz
mv sing-box-$SING_BOX_VERSION-linux-amd64/sing-box sb
rm -rf sing-box*
echo "[bootstrap] Downloaded sb to $SB_DIR/sb"

# sb config
curl -sSL -o config.json https://raw.githubusercontent.com/vevc/one-node/refs/heads/main/xserver-games/sing-box-config.json
openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout key.pem -out cert.pem -subj "/CN=www.bing.com" 2>/dev/null
sed -i "s/YOUR_UUID/$UUID/g" config.json
sed -i "s#YOUR_CERT#$SB_DIR/cert.pem#g" config.json
sed -i "s#YOUR_KEY#$SB_DIR/key.pem#g" config.json

# hy2 & tc sub
hy2Url="hysteria2://$UUID@$DOMAIN:25565?sni=www.bing.com&alpn=h3&insecure=1&allowInsecure=1#$REMARKS_PREFIX-hy2"
echo $hy2Url >> $WS_PLUGIN_DIR/node.txt
tuicUrl="tuic://$UUID%3A$UUID@$DOMAIN:25575?sni=www.bing.com&alpn=h3&insecure=1&allowInsecure=1&congestion_control=bbr#$REMARKS_PREFIX-tuic"
echo $tuicUrl >> $WS_PLUGIN_DIR/node.txt

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

mkdir -p "$(dirname "$WS_CONFIG_PATH")"
cat > "$WS_CONFIG_PATH" <<EOF
programs:
  - name: xy
    directory: "$XY_DIR"
    command: ["sh", "$XY_DIR/startup.sh"]
    logfile: "/dev/null"

  - name: td
    directory: "/home/xgame"
    command: ["sh", "$TD_DIR/startup.sh"]
    logfile: "/dev/null"

  - name: cf
    command: ["sh", "$CF_DIR/startup.sh"]
    logfile: "/dev/null"

  - name: sb
    directory: "$SB_DIR"
    command: ["sh", "$SB_DIR/startup.sh"]
    logfile: "/dev/null"
EOF

echo "[bootstrap] Generated supervisor config: $WS_CONFIG_PATH"
echo "[bootstrap] Bootstrap completed successfully"
