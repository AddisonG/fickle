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
SPOT_FLEET_EXISTS=$(aws ec2 describe-spot-fleet-requests  --query "SpotFleetRequestConfigs[?SpotFleetRequestState=='active'].SpotFleetRequestId" --output text)

if [[ -n "$SPOT_FLEET_EXISTS" ]]; then
    echo "An existing Spot Fleet with the tag 'purpose = fickle' already exists."
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
    fleet_status=$(aws ec2 describe-spot-fleet-requests --spot-fleet-request-ids "$spot_fleet_request_id" --query "SpotFleetRequestConfigs[0].SpotFleetRequestState" --output text)
    fleet_capacity=$(aws ec2 describe-spot-fleet-requests --spot-fleet-request-ids "$spot_fleet_request_id" --query "SpotFleetRequestConfigs[0].SpotFleetRequestConfig.FulfilledCapacity")

    # Check if fleet is active and capacity is fulfilled
    if [[ "${fleet_status}" == "active" && "${fleet_capacity}" == "1.0" ]]; then
        echo "Spot Fleet is active and has the required capacity (1/1)."
        break
    fi

    echo "Current Spot Fleet Status: ${fleet_status}. Fulfilled Capacity: ${fleet_capacity}."

    sleep 1
done

instance_id=$(aws ec2 describe-spot-fleet-requests --spot-fleet-request-ids "${spot_fleet_request_id}" --query "SpotFleetRequestConfigs[0].ActiveInstances[0].InstanceId" --output text)
public_ip=$(aws ec2 describe-instances --instance-ids "${instance_id}" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

echo "Fickle Fleet is ready. See ${public_ip} (${instance_id}) for Fickle."


