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
echo -e "${LIGHT_BLUE_COLOR}v1.0 - Deployment Suite${NO_COLOR}"
echo -e "${RED_COLOR}==================================================${NO_COLOR}"
echo -e "${LIGHT_BLUE_COLOR}    Starting system cleanup...     ${NO_COLOR}"
echo -e "${RED_COLOR}==================================================${NO_COLOR}"

# --- STEP 1 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 1/7]${NO_COLOR} Terminating active services (Caddy, Hysteria and 3x-ui)..."
systemctl stop caddy hysteria-server x-ui 2>/dev/null
systemctl disable caddy hysteria-server x-ui 2>/dev/null

# --- STEP 2 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 2/7]${NO_COLOR} Removing configuration files and binaries..."
rm -rf /etc/caddy
rm -rf /etc/hysteria
rm -rf /usr/bin/caddy
rm -rf /usr/local/bin/hysteria 2>/dev/null
rm -rf /etc/systemd/system/caddy.service
rm -rf /etc/systemd/system/hysteria-server.service

# --- STEP 3 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 3/7]${NO_COLOR} Uninstalling 3x-ui panel..."
if [ -f /usr/local/x-ui/bin/x-ui ]; then
    /usr/local/x-ui/x-ui uninstall -s
    rm -rf /usr/local/x-ui
    rm -rf /etc/x-ui
fi

# --- STEP 4 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 4/7]${NO_COLOR} Purging Docker containers and images..."
if command -v docker &> /dev/null; then
    docker stop $(docker ps -a -q) 2>/dev/null
    docker rm $(docker ps -a -q) 2>/dev/null
    docker system prune -af 2>/dev/null
fi

# --- STEP 5 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 5/7]${NO_COLOR} Wiping project directories and certificates..."
rm -rf /root/projects/mtproto-util
rm -rf /var/www/masq
rm -rf /root/cert/*

# --- STEP 6 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 6/7]${NO_COLOR} Resetting firewall rules to default..."
ufw --force reset
ufw disable

# --- STEP 7 ---
echo -e "\n${LIGHT_BLUE_COLOR}[STEP 7/7]${NO_COLOR} Removing Go environment..."
rm -rf /usr/local/go

# FINAL REPORT
echo -e "\n${RED_COLOR}##################################################${NO_COLOR}"
echo -e "${RED_COLOR}            SHIELD HAS COMPLETELY BEEN REMOVED               ${NO_COLOR}"
echo -e "${RED_COLOR}##################################################${NO_COLOR}"

echo -e "\n${GREEN_COLOR}Cleanup is completed!${NO_COLOR}"
echo -e "Your server is now back to its original state."
echo -e "${LIGHT_BLUE_COLOR}Recommendation:${NO_COLOR} Run 'reboot' to clear up all network interfaces.\n"