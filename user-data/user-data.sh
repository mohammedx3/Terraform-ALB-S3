#!/bin/bash -xe

touch /home/ubuntu/user-data-log.log

echo "$(date +"%T")" "log file created" >> /home/ubuntu/user-data-log.log

sudo apt update -y

echo "$(date +"%T")" "[sudo apt update -y] done" >> /home/ubuntu/user-data-log.log

cd /home/ubuntu

echo "$(date +"%T")" "[cd /home/ubuntu] done" >> /home/ubuntu/user-data-log.log

sudo wget https://github.com/traefik/traefik/releases/download/v1.7.30/traefik_linux-amd64

echo "$(date +"%T")" "[sudo wget https://github.com/traefik/traefik/releases/download/v1.7.30/traefik_linux-amd64] done" >> /home/ubuntu/user-data-log.log

sudo chmod 777 traefik_linux-amd64

echo "$(date +"%T")" "[sudo chmod 777 traefik_linux-amd64] done" >> /home/ubuntu/user-data-log.log

mkdir configs

echo "$(date +"%T")" "[mkdir configs] done" >> /home/ubuntu/user-data-log.log

apt install awscli -y

echo "$(date +"%T")" "[apt install awscli -y] done" >> /home/ubuntu/user-data-log.log

echo "${s3_name}" > s3name.txt

echo "$(date +"%T")" "[echo s3_name > s3name.txt] done" >> /home/ubuntu/user-data-log.log

aws s3 presign s3://${s3_name}/test1.txt > /home/ubuntu/file1_access.txt

echo "$(date +"%T")" "[file1] created" >> /home/ubuntu/user-data-log.log

aws s3 presign s3://${s3_name}/test1.txt > /home/ubuntu/file2_access.txt

echo "$(date +"%T")" "[file2] created" >> /home/ubuntu/user-data-log.log

echo -e '[frontends] \n [frontends.frontend1] \n backend = "backend1" \n  [frontends.frontend1.routes.playgrond] \n  rule = "PathPrefix:/" \n \n[backends] \n  [backends.backend1] \n   [backends.backend1.servers.server1] \n   url = "http://${s3_name}.s3-eu-west-1.amazonaws.com"' > configs/reverse.toml

echo "$(date +"%T")" "[configs/reverse.toml] created" >> /home/ubuntu/user-data-log.log

echo -e 'logLevel = "DEBUG" \ndebug=true \ndefaultEntryPoints = ["http"] \n \n[file] \n directory = "/home/ubuntu/configs" \n watch = true \n[entryPoints] \n [entryPoints.http] \n   address = ":80" \n[traefikLog] \n  filePath = "./traefik.log"' > traefik.toml 

echo "$(date +"%T")" "[traefik.toml] created" >> /home/ubuntu/user-data-log.log

./traefik_linux-amd64

echo "$(date +"%T")" "[traefik] is up and running..." >> /home/ubuntu/user-data-log.log

EOL	