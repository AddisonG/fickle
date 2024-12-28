#!/bin/bash -eo pipefail
FICKLE_VOLUME="vol-083785290bcdd11be"
FICKLE_ENI="eni-08100274fde510b42"
REGION="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')"
INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"

apt-get update
apt-get install awscli -y

aws configure set region ${REGION}

update_tag() {
    TAG_NAME="userdata-status"
    aws ec2 create-tags --resources ${INSTANCE_ID} --tags Key=${TAG_NAME},Value="$1"
}

update_tag "attaching volume"

aws ec2 attach-volume --volume-id ${FICKLE_VOLUME} --instance-id ${INSTANCE_ID} --device /dev/xvdf

update_tag "mounting volume"

mkdir /home/fickle
chown 1000:1000 /home/fickle
for x in {1..5}; do [ -e /dev/xvdf ] && break || sleep 1; done
mount /dev/xvdf /home/fickle

update_tag "running boot script"

/home/fickle/boot/boot.sh

update_tag "complete"
