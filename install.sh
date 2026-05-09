#!/bin/bash
sudo apt-get update && sudo apt-get upgrade -y

stdbuf -oL bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) | tee x-ui.log

# Getting output from 3x-ui query
export XUI_USER=$(sed 's/\x1b\[[0-9;]*m//g' x-ui.log | grep -i "Username:" | awk '{print $NF}')
export XUI_PASS=$(sed 's/\x1b\[[0-9;]*m//g' x-ui.log | grep -i "Password:" | awk '{print $NF}')
export XUI_URL=$(sed 's/\x1b\[[0-9;]*m//g' x-ui.log | grep -i "Access URL:" | awk '{print $NF}')

rm -f x-ui.log

# Configuring env vars
LIGHT_BLUE_COLOR='\e[94m'
GREEN_COLOR='\e[32m'
NAVY_COLOR='\e[34m' 
RED_COLOR='\e[31m' 
NO_COLOR='\e[0m'

# Configuring local vars
export DOMAIN="<domain>" 

export NAIVE_PORT=8443
export NAIVE_USER=$(openssl rand -hex 8)
export NAIVE_PASS=$(openssl rand -hex 12)

export HYSTERIA_PORT=3724 # World Of Warcraft
export HYSTERIA_USER=$(openssl rand -hex 8)
export HYSTERIA_PASS=$(openssl rand -hex 12)
export HYSTERIA_EMAIL="<email>"

export BOT_TOKEN="<token>"
export BOT_GROUP_ID=-0
export BOT_ADMIN_ID=0

# === NAIVE PROXY ===

wget https://go.dev/dl/go1.26.2.linux-amd64.tar.gz

rm -rf /usr/local/go && tar -C /usr/local -xzf go1.26.2.linux-amd64.tar.gz

export PATH=$PATH:/usr/local/go/bin

go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive

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
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
User=root
Group=root
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now caddy
systemctl start caddy

# === HYSTERIA2 === 

bash <(curl -fsSL https://get.hy2.sh/)

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

# === MTPROTO BOT ===

curl -fsSL https://get.docker.com | sh

sudo apt-get install git -y 

mkdir -p /root/projects/mtproto-util

git clone https://github.com/artndev/mtproto-util.git /root/projects/mtproto-util

cat <<EOF > /root/projects/mtproto-util/.env
BOT_TOKEN=$BOT_TOKEN
GROUP_ID=$BOT_GROUP_ID
ADMIN_ID=$BOT_ADMIN_ID
EOF

chmod +x /root/projects/mtproto-util/deploy.sh
/root/projects/mtproto-util/deploy.sh

# Setting up firewall

sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow $NAIVE_PORT/tcp
sudo ufw allow $HYSTERIA_PORT/udp
ufw --force enable

# Displaying results

sudo ufw status verbose

sudo ss -tultp

docker ps -a

echo -e "\n${GREEN_COLOR}=== 3x-ui Panel ===${NO_COLOR}"
echo -e "User: $XUI_USER"
echo -e "Pass: $XUI_PASS"
echo -e "Panel URL:  $XUI_URL"

echo -e "\n${LIGHT_BLUE_COLOR}=== Naive Proxy ===${NO_COLOR}"
echo -e "User: $NAIVE_USER"
echo -e "Pass: $NAIVE_PASS"
echo -e "Port: $NAIVE_PORT"
echo -e "URL: naive+quic://${NAIVE_USER}:${NAIVE_PASS}@${DOMAIN}:${NAIVE_PORT}?sni=${DOMAIN}#Naive"
echo -e "===================\n"

echo -e "\n${RED_COLOR}=== Hysteria2 ===${NO_COLOR}"
echo -e "User: $HYSTERIA_USER"
echo -e "Pass: $HYSTERIA_PASS"
echo -e "Port: $HYSTERIA_PORT"
echo -e "URL: hy2://${HYSTERIA_USER}:${HYSTERIA_PASS}@${DOMAIN}:${HYSTERIA_PORT}?sni=${DOMAIN}&alpn=h3&insecure=0&allowInsecure=0#Hysteria2"
echo -e "===================\n"

echo -e "\n${NAVY_COLOR}=== MTProto Bot ===${NO_COLOR}"
echo -e "Port: 9443"
echo -e "===================\n"