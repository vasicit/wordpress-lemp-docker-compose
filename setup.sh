#!/bin/bash

echo "Setting up Docker Compose"

curl -L --fail https://github.com/docker/compose/releases/download/1.29.2/run.sh -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

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
systemctl enable /etc/systemd/system/start-container.service --now
systemctl start update.timer
