#!/bin/bash

touch /tmp/fickle

hostname -b "ficklehost"

# Replace the ubuntu user with fickle
usermod -l fickle -d /home/fickle -m ubuntu
groupmod -n fickle ubuntu
usermod -aG www-data fickle
usermod -aG fastapiuser fickle
rm -rf /home/ubuntu
rm /etc/sudoers.d/90-cloud-init-users
rm -f /etc/update-motd.d/*
echo "fickle ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create the API user
adduser --system --group --no-create-home --shell /bin/false fastapiuser
#usermod -aG www-data fastapiuser
sudo ln -siT /home/fickle/web/rpg/api/rpg-api /usr/lib/python3/dist-packages/rpg_api

# Install stuff
apt install -y npm nodejs curl nginx python3-pip jq tree openjdk-21-jre-headless
apt upgrade
pip install uvicorn fastapi sqlalchemy
npm install -g n
n stable
npm install -g npm create-react-app

cat >> /etc/fstab <<EOF
overlay /home/fickle/overlay/merged overlay lowerdir=/etc,upperdir=/home/fickle/overlay/etc,workdir=/home/fickle/overlay/temp 0 0
/home/fickle/overlay/merged /etc none bind 0 0
EOF

# "Are you bind mounting an overlay fs over /etc?" - You, probably
mount -t overlay overlay -o lowerdir=/etc,upperdir=/home/fickle/overlay/etc,workdir=/home/fickle/overlay/temp /home/fickle/overlay/merged
mount --bind /home/fickle/overlay/merged /etc

service nginx restart
#systemctl enable dnd-api
#systemctl start dnd-api

# Create 1GB swapfile
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

FICKLE_IP="54.253.60.92"
REGION="ap-southeast-2"
INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
aws ec2 associate-address --instance-id "${INSTANCE_ID}" --public-ip "${FICKLE_IP}" --region "${REGION}"

# Start minecraft server
sudo -u fickle /home/fickle/minecraft/start.sh
