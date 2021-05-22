#!/bin/bash -xe

sudo apt update -y
cd /home/ubuntu
sudo wget https://github.com/traefik/traefik/releases/download/v1.7.30/traefik_linux-amd64
sudo chmod 777 traefik_linux-amd64
mkdir configs

apt install awscli -y

echo -e '[frontends] \n [frontends.frontend1] \n backend = "backend1" \n  [frontends.frontend1.routes.playgrond] \n  rule = "PathPrefix:/" \n \n[backends] \n  [backends.backend1] \n   [backends.backend1.servers.server1] \n   url = "http://${s3_name}.s3-eu-west-1.amazonaws.com"' > configs/reverse.toml
echo -e 'logLevel = "DEBUG" \ndebug=true \ndefaultEntryPoints = ["http"] \n \n[file] \n directory = "/home/ubuntu/configs" \n watch = true \n[entryPoints] \n [entryPoints.http] \n   address = ":80" \n[traefikLog] \n  filePath = "./traefik.log"' > traefik.toml 
./traefik_linux-amd64
EOL	