#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Check logged in
if aws sts get-caller-identity --query 'Account' --output text > /dev/null 2>&1; then
    echo "AWS login successful."
else
    echo "AWS login failed. Please ensure you are logged in."
    exit 1
fi

# Check there is not an existing spot fleet with a tag "purpose = fickle"
SPOT_FLEET_EXISTS=$(aws ec2 describe-spot-fleet-requests \
    --query "SpotFleetRequestConfigs[?SpotFleetRequestState=='active' && Tags[?Key=='purpose' && Value=='fickle']].SpotFleetRequestId" \
    --output text
)

if [[ -n "$SPOT_FLEET_EXISTS" ]]; then
    echo "An active Spot Fleet with tag 'purpose=fickle' already exists: $SPOT_FLEET_EXISTS"
    exit 1
fi

# Start spot fleet
JSON_FILE="$SCRIPT_DIR/spot_fleet_request.json"
response=$(aws ec2 request-spot-fleet --spot-fleet-request-config file://"${JSON_FILE}")

spot_fleet_request_id=$(echo "$response" | jq -r '.SpotFleetRequestId')

if [[ "$spot_fleet_request_id" == "null" || -z "$spot_fleet_request_id" ]]; then
    echo "Error: Unable to retrieve Spot Fleet Request ID."
    exit 1
fi

echo "Spot Fleet Request created with ID: $spot_fleet_request_id"

# Poll until Spot Fleet is active and has 1/1 capacity
echo "Polling Spot Fleet status..."
while true; do
    sleep 2
    fleet_status=$(aws ec2 describe-spot-fleet-requests --spot-fleet-request-ids "$spot_fleet_request_id" --query "SpotFleetRequestConfigs[0].SpotFleetRequestState" --output text)
    fleet_capacity=$(aws ec2 describe-spot-fleet-requests --spot-fleet-request-ids "$spot_fleet_request_id" --query "SpotFleetRequestConfigs[0].SpotFleetRequestConfig.FulfilledCapacity")

    # Check if fleet is active and capacity is fulfilled
    if [[ "${fleet_status}" == "active" && "${fleet_capacity}" == "1.0" ]]; then
        echo "Spot Fleet is active and has the required capacity (1/1)."
        break
    fi

    echo "Current Spot Fleet Status: ${fleet_status}. Fulfilled Capacity: ${fleet_capacity}."
done

echo "Fleet completed. Finding instance"

while true; do
    sleep 2
    instance_id=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=Fickle" "Name=instance-state-name,Values=pending,running" --query "Reservations[*].Instances[*].InstanceId" --output text)
    public_ip=$(aws ec2 describe-instances --instance-ids "${instance_id}" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
    if [[ -n ${public_ip} ]]; then
        break
    fi
done

echo "Fickle Fleet is ready. See ${public_ip} (${instance_id}) for Fickle."


# Check if hosted zone already exists
echo "Checking if hosted zone for gourluck.click already exists..."
existing_zone=$(aws route53 list-hosted-zones-by-name --dns-name "gourluck.click." --max-items 1 --query 'HostedZones[?Name==`gourluck.click.`].Id' --output text | sed 's|/hostedzone/||')

if [[ -z "$existing_zone" ]]; then
    echo "Creating new hosted zone for gourluck.click..."
    route_53_output=$(aws route53 create-hosted-zone \
        --name "gourluck.click" \
        --caller-reference "$(date +%s)" \
        --hosted-zone-config "PrivateZone=false" \
        --no-cli-auto-prompt)

    # Extract the hosted zone ID from the output
    hosted_zone_id=$(echo "$route_53_output" | jq -r '.HostedZone.Id' | sed 's|/hostedzone/||')

    echo "Created new hosted zone with ID: $hosted_zone_id"

    # Get nameservers from the new hosted zone and update domain
    echo "Updating domain nameservers to match new hosted zone..."
    nameservers=$(aws route53 get-hosted-zone --id $hosted_zone_id --query 'DelegationSet.NameServers[]' --output text)

    # Convert nameservers to the format needed for update-domain-nameservers
    ns_params=""
    for ns in $nameservers; do
        ns_params="$ns_params Name=$ns"
    done

    aws route53domains update-domain-nameservers \
        --domain-name gourluck.click \
        --nameservers $ns_params \
        --region us-east-1

    echo "Domain nameservers updated. DNS propagation may take a few minutes."
    # Allow some time for the hosted zone to be created
    # sleep 5
else
    echo "Using existing hosted zone with ID: $existing_zone"
    hosted_zone_id=$existing_zone
fi

echo "Updating Route53 records to bind gourluck.click and all subdomains to IP address: $public_ip"

upsert_53_doc=$(cat <<EOF
{
    "Comment": "Point to EC2",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "gourluck.click",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [
                    { "Value": "$public_ip" }
                ]
            }
        },
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "*.gourluck.click",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [
                    { "Value": "$public_ip" }
                ]
            }
        }
    ]
}
EOF
)

aws route53 change-resource-record-sets \
    --hosted-zone-id "$hosted_zone_id" \
    --change-batch "$upsert_53_doc"

# Dig a bunch, lol
#dig gourluck.click @8.8.8.8
#dig gourluck.click @1.1.1.1
