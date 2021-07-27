#!/bin/bash

echo "Setting up Docker Compose"

mkdir -p /opt/bin
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /opt/bin/docker-compose
chmod +x /opt/bin/docker-compose

echo "Please type the domain name without the https:// prefix:"
read -p 'Domain name: ' domainvar
echo "Please type the email address for renewal notices:"
read -p 'Email address: ' emailvar
echo "Setting up domain name in nginx.conf.."
sed -i "s/DOMAINNAME/$domainvar/g" nginx.conf

echo "Installing temporary SSL certificates with LetsEncrypt"

docker run -it -p 80:80 -v $(pwd)/letsencrypt:/etc/letsencrypt certbot/certbot certonly --non-interactive --standalone --agree-tos -m $emailvar -d $domainvar

echo "Setting up container auto-start service at boot time and daily update timer"

cp *.service /etc/systemd/system/
cp *.timer /etc/systemd/system/
sudo systemctl enable /etc/systemd/system/start-container.service --now
sudo systemctl start update.timer
