#!/usr/bin/env bash

cd /home/team/shared

XRAY_VERSION="26.3.27"
ARGO_VERSION="2026.3.0"
TTYD_VERSION="1.7.7"

curl -sSL -o Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/download/v$XRAY_VERSION/Xray-linux-64.zip
unzip -q Xray-linux-64.zip
mv xray /usr/local/bin/xy
rm -rf *

curl -sSL -o xy.json https://raw.githubusercontent.com/vevc/one-node/refs/heads/dev/cto-new/xray-config.json
sed -i "s/YOUR_UUID/$U/g" xy.json

curl -sSL -o /usr/local/bin/cf https://github.com/cloudflare/cloudflared/releases/download/$ARGO_VERSION/cloudflared-linux-amd64
chmod +x /usr/local/bin/cf

curl -sSL -o /usr/local/bin/td https://github.com/tsl0922/ttyd/releases/download/$TTYD_VERSION/ttyd.x86_64
chmod +x /usr/local/bin/td

# xy startup
cat > /etc/systemd/system/xy.service <<EOF
[Unit]
Description=xy
After=network.target

[Service]
ExecStart=xy -c /home/team/shared/xy.json
StandardOutput=null
StandardError=null
Restart=always

[Install]
WantedBy=multi-user.target

EOF

# cf startup
cat > /etc/systemd/system/cf.service <<EOF
[Unit]
Description=cf
After=network.target

[Service]
ExecStart=cf tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token $T
StandardOutput=null
StandardError=null
Restart=always

[Install]
WantedBy=multi-user.target

EOF

# td startup
cat > /etc/systemd/system/td.service <<EOF
[Unit]
Description=td
After=network.target

[Service]
ExecStart=/usr/local/bin/td -p 80 -W env HISTFILE=/dev/null bash
StandardOutput=null
StandardError=null
Restart=always

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl enable --now xy cf td

# firefox
cat > /home/team/shared/docker-compose.yml <<EOF
services:
  firefox:
    image: jlesage/firefox
    container_name: firefox
    restart: unless-stopped
    ports:
      - '5800:5800'
    volumes:
      - '/home/team/shared/firefox/config:/config:rw'
    environment:
      LANG: zh_CN.UTF-8
      ENABLE_CJK_FONT: 1
      VNC_PASSWORD: '${P}'

EOF
docker compose up -d

# sub info
cat > /home/team/shared/node.txt <<EOF
vless://$U@$D:443?encryption=none&security=tls&sni=$D&fp=chrome&insecure=0&allowInsecure=0&type=ws&host=$D&path=%2F#cto-ws-argo

EOF
