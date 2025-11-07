#!/bin/bash -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Check logged in
aws sts get-caller-identity

# Update launch template if local file differs from AWS
echo "Checking launch template for changes..."
TEMPLATE_ID="lt-00499d145eae50fd3"

# Get current AWS template data
current_template=$(aws ec2 describe-launch-template-versions --launch-template-id $TEMPLATE_ID --versions '$Latest' --query 'LaunchTemplateVersions[0].LaunchTemplateData' --output json)

# Get local template data
local_template=$(jq '.LaunchTemplateVersions[0].LaunchTemplateData' "$SCRIPT_DIR/launch_template.json")

# Compare templates (ignoring metadata like version numbers)
if ! diff <(echo "$current_template" | jq -S .) <(echo "$local_template" | jq -S .) > /dev/null 2>&1; then
    echo "Launch template changes detected. Creating new version..."

    # Create new version with local template data
    aws ec2 create-launch-template-version \
        --launch-template-id $TEMPLATE_ID \
        --launch-template-data file://<(echo "$local_template") \
        --version-description "Updated from local file $(date)"

    # Set as default version
    latest_version=$(aws ec2 describe-launch-template-versions --launch-template-id $TEMPLATE_ID --query 'LaunchTemplateVersions[0].VersionNumber' --output text)
    aws ec2 modify-launch-template --launch-template-id $TEMPLATE_ID --default-version $latest_version

    echo "Launch template updated to version $latest_version"
else
    echo "Launch template is up to date"
fi

# Create all base level resources
# TODO
