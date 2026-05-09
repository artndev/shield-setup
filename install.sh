#!/bin/bash

# Available colors
LIGHT_BLUE_COLOR='\e[94m'
GREEN_COLOR='\e[32m'
NAVY_COLOR='\e[34m' 
RED_COLOR='\e[31m' 
NO_COLOR='\e[0m'

# Clear screen
clear

# GREETING MESSAGE
echo -e "${NAVY_COLOR}"
echo "  ██████  ██   ██ ██ ███████ ██      ██████  "
echo " ██       ██   ██ ██ ██      ██      ██   ██ "
echo "  █████   ███████ ██ █████   ██      ██   ██ "
echo "       ██ ██   ██ ██ ██      ██      ██   ██ "
echo "  ██████  ██   ██ ██ ███████ ███████ ██████  "
echo -e "${LIGHT_BLUE_COLOR}\nv1.0 - Deployment Suite${NO_COLOR}"
echo -e "${RED_COLOR}==================================================${NO_COLOR}"
echo -e "${LIGHT_BLUE_COLOR}Starting installation...${NO_COLOR}"
echo -e "${RED_COLOR}==================================================${NO_COLOR}"

# Check args passed via curl
if [ "$#" -lt 5 ]; then
    echo -e "${RED_COLOR}Error: Not enough arguments!${NO_COLOR}"
    echo -e "Usage: curl -sL <url> | bash -s -- <domain> <email> <bot_token> <group_id> <admin_id>"
    echo -e "Example: ... | bash -s -- \"example.com\" \"admin@mail.com\" \"123:ABC\" \"-100...\" \"567\""
    exit 1
fi

# Set vars with values fetched from args
export DOMAIN="$1"
export HYSTERIA_EMAIL="$2"
export BOT_TOKEN="$3"
export BOT_GROUP_ID="$4"
export BOT_ADMIN_ID="$5"

# Constants
export NAIVE_PORT=8443
export NAIVE_USER=$(openssl rand -hex 8)
export NAIVE_PASS=$(openssl rand -hex 12)

export HYSTERIA_PORT=3724
export HYSTERIA_USER=$(openssl rand -hex 8)
export HYSTERIA_PASS=$(openssl rand -hex 12)

# --- STEP 1 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 1/12]${NO_COLOR} Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y

# --- STEP 2 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 2/12]${NO_COLOR} Deploying 3x-ui panel..."
stdbuf -oL bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) | tee x-ui.log

# --- STEP 3 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 3/12]${NO_COLOR} Parsing credentials from 3x-ui logs..."
export XUI_USER=$(sed 's/\x1b\[[0-9;]*m//g' x-ui.log | grep -i "Username:" | awk '{print $NF}')
export XUI_PASS=$(sed 's/\x1b\[[0-9;]*m//g' x-ui.log | grep -i "Password:" | awk '{print $NF}')
export XUI_URL=$(sed 's/\x1b\[[0-9;]*m//g' x-ui.log | grep -i "Access URL:" | awk '{print $NF}')
rm -f x-ui.log

# --- STEP 4 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 4/12]${NO_COLOR} Installing Go environment..."
wget https://go.dev/dl/go1.26.2.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.26.2.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# --- STEP 5 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 5/12]${NO_COLOR} Building Caddy binary with xcaddy..."
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive

# --- STEP 6 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 6/12]${NO_COLOR} Configuring Caddy as NaiveProxy..."
mkdir -p /etc/caddy
cat > /etc/caddy/Caddyfile << EOF
{
  auto_https off
  order forward_proxy before reverse_proxy
}

:$NAIVE_PORT, $DOMAIN {
  tls /root/cert/$DOMAIN/fullchain.pem /root/cert/$DOMAIN/privkey.pem

  forward_proxy {
    basic_auth $NAIVE_USER $NAIVE_PASS
    hide_ip
    hide_via
    probe_resistance
  }

  reverse_proxy $DOMAIN {
    header_up Host {upstream_hostport}
  }
}
EOF

chmod +x caddy
sudo mv caddy /usr/bin/caddy

cat > /etc/systemd/system/caddy.service << EOF
[Unit]
Description=Caddy
After=network.target network-online.target
[Service]
User=root
Group=root
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now caddy
systemctl start caddy

# --- STEP 7 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 7/12]${NO_COLOR} Installing Hysteria2 core..."
bash <(curl -fsSL https://get.hy2.sh/)

# --- STEP 8 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 8/12]${NO_COLOR} Setting up Hysteria2 config and masquerade..."
mkdir -p /var/www/masq
tee /var/www/masq/index.html >/dev/null << 'HTML'
<!DOCTYPE html><html><head><meta charset="utf-8"><title>Please wait</title><style>body{background:#080808;height:100vh;margin:0;display:flex;flex-direction:column;align-items:center;justify-content:center;font-family:sans-serif}.dots{display:flex;gap:15px;margin-bottom:30px}.d{width:20px;height:20px;background:#fff;border-radius:50%;animation:b 1.4s infinite ease-in-out both}.d:nth-child(1){animation-delay:-0.32s}.d:nth-child(2){animation-delay:-0.16s}@keyframes b{0%,80%,100%{transform:scale(0);opacity:0.2}40%{transform:scale(1);opacity:1}}.t{color:#555;font-size:14px;letter-spacing:2px;font-weight:600}</style></head><body><div class="dots"><div class="d"></div><div class="d"></div><div class="d"></div></div><div class="t">RETRYING CONNECTION</div></body></html>
HTML

cat > /etc/hysteria/config.yaml << EOF
listen: 0.0.0.0:$HYSTERIA_PORT
acme:
  type: http
  domains:
    - $DOMAIN
  email: $HYSTERIA_EMAIL
auth:
  type: userpass
  userpass:
    $HYSTERIA_USER: $HYSTERIA_PASS
masquerade:
  type: file
  file:
    dir: /var/www/masq
  listenHTTP: :80
  listenHTTPS: :$HYSTERIA_PORT
  forceHTTPS: true
EOF

systemctl daemon-reload
systemctl enable --now hysteria-server.service
systemctl start hysteria-server.service

# --- STEP 9 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 9/12]${NO_COLOR} Installing Docker environment..."
curl -fsSL https://get.docker.com | sh
sudo apt-get install git -y 

# --- STEP 10 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 10/12]${NO_COLOR} Deploying Telegram bot..."
mkdir -p /root/projects/mtproto-util
git clone https://github.com/artndev/mtproto-util.git /root/projects/mtproto-util

cat <<EOF > /root/projects/mtproto-util/.env
BOT_TOKEN=$BOT_TOKEN
GROUP_ID=$BOT_GROUP_ID
ADMIN_ID=$BOT_ADMIN_ID
EOF

chmod +x /root/projects/mtproto-util/deploy.sh
/root/projects/mtproto-util/deploy.sh

# --- STEP 11 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 11/12]${NO_COLOR} Hardening system with firewall rules..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow $NAIVE_PORT/tcp
sudo ufw allow $HYSTERIA_PORT/udp
ufw --force enable

# --- STEP 12 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 12/12]${NO_COLOR} Cleaning up and generating final report..."

# Final Output
echo -e "\n${NAVY_COLOR}##################################################${NO_COLOR}"
echo -e "${NAVY_COLOR}SHIELD DEPLOYMENT HAS BEEN COMPLETED${NO_COLOR}"
echo -e "${NAVY_COLOR}##################################################${NO_COLOR}"

echo -e "\n${GREEN_COLOR}=== 3x-ui Panel ===${NO_COLOR}"
echo -e "User: $XUI_USER"
echo -e "Pass: $XUI_PASS"
echo -e "Panel URL:  $XUI_URL"

echo -e "\n${LIGHT_BLUE_COLOR}=== Naive Proxy ===${NO_COLOR}"
echo -e "User: $NAIVE_USER"
echo -e "Pass: $NAIVE_PASS"
echo -e "Port: $NAIVE_PORT"
echo -e "URL: naive+quic://${NAIVE_USER}:${NAIVE_PASS}@${DOMAIN}:${NAIVE_PORT}?sni=${DOMAIN}#Naive"

echo -e "\n${RED_COLOR}=== Hysteria2 ===${NO_COLOR}"
echo -e "User: $HYSTERIA_USER"
echo -e "Pass: $HYSTERIA_PASS"
echo -e "Port: $HYSTERIA_PORT"
echo -e "URL: hy2://${HYSTERIA_USER}:${HYSTERIA_PASS}@${DOMAIN}:${HYSTERIA_PORT}?sni=${DOMAIN}&alpn=h3&insecure=0&allowInsecure=0#Hysteria2"

echo -e "\n${NAVY_COLOR}=== MTProto Bot ===${NO_COLOR}"
echo -e "Port: 9443"
echo -e "===================\n"