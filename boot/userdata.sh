#!/bin/bash
FICKLE_VOLUME="vol-083785290bcdd11be"
FICKLE_IP="3.24.16.174"
REGION="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')"
INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"

apt-get update
apt-get install awscli -y

aws ec2 attach-volume --volume-id ${FICKLE_VOLUME} --instance-id ${INSTANCE_ID} --device /dev/xvdf --region ${REGION}

mkdir /home/fickle
chown 1000:1000 /home/fickle
for x in {1..5}; do [ -e /dev/xvdf ] && break || sleep 1; done
mount /dev/xvdf /home/fickle
/home/fickle/boot/boot.sh

aws ec2 associate-address --instance-id ${INSTANCE_ID} --public-ip ${FICKLE_IP} --region ${REGION}
