#!/bin/bash

FICKLE_VOLUME="vol-083785290bcdd11be"
FICKLE_ENI="eni-08100274fde510b42"
REGION="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')"
INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"

apt-get update
apt-get install awscli -y

aws configure set region ${REGION}

update_tag() {
    logger "$1"
    TAG_NAME="userdata-status"
    aws ec2 create-tags --resources ${INSTANCE_ID} --tags Key=${TAG_NAME},Value="$1"
}

update_tag "attaching volume"

aws ec2 attach-volume --volume-id ${FICKLE_VOLUME} --instance-id ${INSTANCE_ID} --device /dev/xvdf

update_tag "mounting volume"

mkdir /home/fickle
chown 1000:1000 /home/fickle

for x in {1..5}; do
    sleep 1
    VOL_INFO=$(lsblk -o NAME,SERIAL | grep "${FICKLE_VOLUME:4}")

    if [[ -n "$VOL_INFO" ]]; then
        TRUE_VOL=$(echo "$VOL_INFO" | awk '{print $1}')
        break
    fi
done

if [[ -z "${TRUE_VOL}" ]]; then
    update_tag "Volume '${FICKLE_VOLUME}' not found after multiple attempts."
    exit 1
fi

mount /dev/${TRUE_VOL} /home/fickle

update_tag "running boot script"

/home/fickle/boot/boot.sh

update_tag "complete"
