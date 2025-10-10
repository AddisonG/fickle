#!/bin/bash

# Fetch the Spot Fleet request ID based on the tag
spot_fleet_request_id=$(aws ec2 describe-spot-fleet-requests \
  --query "SpotFleetRequestConfigs[?SpotFleetRequestState=='active' && Tags[?Key=='purpose' && Value=='fickle']].SpotFleetRequestId" \
  --output text
)

# Check if Spot Fleet exists and delete it
if [[ -n "$spot_fleet_request_id" && "$spot_fleet_request_id" != "None" ]]; then
    echo "Deleting Spot Fleet with ID: $spot_fleet_request_id"
    aws ec2 cancel-spot-fleet-requests --spot-fleet-request-ids "$spot_fleet_request_id" --terminate-instances
else
    echo "No Spot Fleet with the tag 'purpose=fickle' found."
fi

# Fetch the Route 53 hosted zone ID for gourluck.click
hosted_zone_id=$(aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='gourluck.click.'].Id" \
  --output text | sed 's|/hostedzone/||')

echo "Checking for DNS records to clean up"
# Fetch the Route 53 hosted zone ID for gourluck.click
hosted_zone_id=$(aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='gourluck.click.'].Id" \
  --output text | sed 's|/hostedzone/||')

# Just delete all non-required records by getting them and deleting them
if [[ -n "$hosted_zone_id" && "$hosted_zone_id" != "None" ]]; then
    echo "Deleting all A records from hosted zone $hosted_zone_id"

    # Get all A records and delete them in one batch
    aws route53 list-resource-record-sets --hosted-zone-id "$hosted_zone_id" \
        --query "ResourceRecordSets[?Type=='A']" --output json | \
    jq '{Changes: [.[] | {Action: "DELETE", ResourceRecordSet: .}]}' | \
    aws route53 change-resource-record-sets --hosted-zone-id "$hosted_zone_id" --change-batch file:///dev/stdin 2>/dev/null || echo "No A records to delete"
fi


# Check if hosted zone exists and delete it
if [[ -n "$hosted_zone_id" && "$hosted_zone_id" != "None" ]]; then
    echo "Deleting Route 53 hosted zone for gourluck.click with ID: $hosted_zone_id"
    aws route53 delete-hosted-zone --id "$hosted_zone_id"

    # Set nameservers to clearly broken/unset values
    echo "Setting domain nameservers to broken state..."
    aws route53domains update-domain-nameservers \
        --domain-name gourluck.click \
        --nameservers Name=example.com Name=example.net \
        --region us-east-1
    echo "Domain nameservers set to example.com/example.net (broken state)"
else
    echo "No Route 53 hosted zone found for gourluck.click."
fi

echo "Cleanup completed."
