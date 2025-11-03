#!/usr/bin/env sh

set -e

DOMAIN="${DOMAIN:-example.com}"
REMARKS="${REMARKS:-webhostmost}"
WEB_PATH="${WEB_PATH:-/$(openssl rand -base64 21 | tr -dc 'A-Za-z0-9' | head -c 14)}"

# Download application files
cd $HOME/domains/$DOMAIN/public_html
curl -sSL -o app.js https://raw.githubusercontent.com/vevc/nodejs-vless/refs/heads/main/app.ext.js
curl -sSL -o package.json https://raw.githubusercontent.com/vevc/nodejs-vless/refs/heads/main/package.json

# Generate UUID
path_md5=$(echo -n "$WEB_PATH" | md5sum | awk '{print $1}')
uuid_part1=$(echo "$path_md5" | cut -c1-8)
uuid_part2=$(echo "$path_md5" | cut -c9-12)
uuid_part3=$(echo "$path_md5" | cut -c13-16)
uuid_part4=$(echo "$path_md5" | cut -c17-20)
uuid_part5=$(echo "$path_md5" | cut -c21-32)
UUID="$uuid_part1-$uuid_part2-$uuid_part3-$uuid_part4-$uuid_part5"

# Install website
cp /usr/sbin/cloudlinux-selector $HOME/cx
$HOME/cx create --json --interpreter=nodejs --user=`whoami` --app-root=$HOME/domains/$DOMAIN/public_html --app-uri=/ --version=22 --app-mode=Production --startup-file=app.js --env-vars='{"UUID":"'$UUID'","DOMAIN":"'$DOMAIN'","REMARKS":"'$REMARKS'","WEB_SHELL":"on"}'
$HOME/nodevenv/domains/$DOMAIN/public_html/22/bin/npm install
rm -rf $HOME/.npm/_logs/*.log

# Keep-alive
mkdir -p $HOME/app
cd $HOME/app
curl -sSL -o backup.sh https://raw.githubusercontent.com/vevc/one-node/refs/heads/main/webhostmost/cron.sh
sed -i "s/YOUR_DOMAIN/$DOMAIN/g" backup.sh
chmod +x backup.sh
(crontab -l 2>/dev/null; echo "* * * * * $HOME/app/backup.sh >> $HOME/app/backup.log") | crontab -

# Print access information
ACCESS_URL="https://$DOMAIN$WEB_PATH"
echo "============================================================"
echo "✅ Service Ready – Access Information"
echo "------------------------------------------------------------"
echo "📁 Path        : $WEB_PATH"
echo "🧬 UUID        : $UUID"
echo "🌐 Access URL  : $ACCESS_URL"
echo "============================================================"
