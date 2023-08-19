#!/bin/bash

#https://t.me/P_tech2024 

# Function to print characters with delay
print_with_delay() {
    text=$1
    delay=$2
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
}

# Introduction animation
print_with_delay "Welcome To Juicity --->Created by :Peyman --> https://github.com/Ptechgithub" 0.02
echo -e "\n"

# Install required packages
apt-get update
apt-get install -y unzip jq

# Detect OS and download the corresponding release
OS=$(uname -s)
if [ "$OS" != "Linux" ]; then
    echo "Unsupported OS: $OS"
    exit 1
fi

LATEST_RELEASE_URL=$(curl --silent "https://api.github.com/repos/juicity/juicity/releases" | jq -r '.[0].assets[] | select(.name == "juicity-linux-x86_64.zip") | .browser_download_url')

# Download and extract to /root/juicity
mkdir -p /root/juicity
curl -L $LATEST_RELEASE_URL -o /root/juicity/juicity.zip
unzip -q /root/juicity/juicity.zip -d /root/juicity

# Delete all files except juicity-server
find /root/juicity ! -name 'juicity-server' -type f -exec rm -f {} +

# Set permissions
chmod +x /root/juicity/juicity-server

# Read user input for configuration
read -p "Enter listen port (or press enter to random port): " PORT
[[ -z "$PORT" ]] && PORT=$((RANDOM % 65500 + 1))

read -p "Enter password (or press enter for a random 6-character password): " PASSWORD

if [[ -z "$PASSWORD" ]]; then
  PASSWORD=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 6 | head -n 1)
fi
UUID=$(uuidgen)

# Generate private key and certificate
openssl ecparam -genkey -name prime256v1 -out /root/juicity/private.key
openssl req -new -x509 -days 36500 -key /root/juicity/private.key -out /root/juicity/fullchain.cer -subj "/CN=speedtest.net"

# Calculate the URL-safe Base64 encoded SHA-256 hash of the certificate chain
CERT_HASH=$(openssl x509 -noout -fingerprint -sha256 -inform pem -in /root/juicity/fullchain.cer | awk -F '=' '{print $2}' | tr -d ':' | tr 'A-F' 'a-f' | xxd -r -p | base64 -w0 | sed 's/\//%2F/g' | sed 's/=/%3D/g')

# Create config_server.json
cat > /root/juicity/config_server.json <<EOL
{
  "listen": ":$PORT",
  "users": {
    "$UUID": "$PASSWORD"
  },
  "certificate": "/root/juicity/fullchain.cer",
  "private_key": "/root/juicity/private.key",
  "congestion_control": "bbr",
  "log_level": "info"
}
EOL

# Create systemd service file
cat > /etc/systemd/system/juicity.service <<EOL
[Unit]
Description=juicity-server Service
Documentation=https://github.com/juicity/juicity
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
Environment=QUIC_GO_ENABLE_GSO=true
ExecStart=/root/juicity/./juicity-server run -c /root/juicity/config_server.json
StandardOutput=file:/root/juicity/juicity-server.log
StandardError=file:/root/juicity/juicity-server.log
Restart=on-failure
LimitNPROC=512
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable juicity
systemctl start juicity
systemctl restart juicity


# Prompt user for choice
read -p "Select an option (1 or 2): 1) Irancell--> IPV6   2) Hamrah-Aval--> IPV4: " choice

case $choice in
    1)
        # Get IPv6 address
        IPv6_ADDRESS=$(ip -6 addr show dev eth0 | awk '/inet6 .*global/{print $2}' | cut -d '/' -f 1)
        
        # Original share link
        SHARE_LINK/root/juicity/juicity/juicity-server generate-share/root/juicity/juicity/config_server.json)

        # Replace IPv4 with IPv6 in the share link
        SHARE_LINK_IPV6=$(echo "$SHARE_LINK_IPV4" | sed "s/[0-9]\+\(\.[0-9]\+\)\{3\}/[$IPv6_ADDRESS]/g")

        echo "----------------------------------------------------------"
        echo ""
        echo "Link with IPv6: -->  $SHARE_LINK_IPV6"
        echo "----------------------------------------------------------"
        echo "$SHARE_LINK_IPV6" > link.txt  #save
        ;;        
    2)
       # Original share link
        SHARE_LINK_IPV4=$("juicity://$UUID:$PASSWORD@[$IPv4_ADDRESS]:$PORT/?congestion_control=bbr&sni=www.speedtest.net&allow_insecure=0&pinned_certchain_sha256=$CERT_HASH")
        echo "----------------------------------------------------------"
        echo " "
        echo "Link with IPv4: -->  $SHARE_LINK_IPV4"
        echo "----------------------------------------------------------"
        echo "$SHARE_LINK_IPV4" > link.txt  #save
        ;; 
    *)
        echo "Invalid choice. Please select 1 or 2."
        ;;
esac
