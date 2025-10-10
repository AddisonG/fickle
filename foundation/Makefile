# Global variables
REGION = ap-southeast-2
VOLUME_ID = vol-083785290bcdd11be
DOMAIN = gourluck.click
TAG_PURPOSE = fickle
INSTANCE_NAME = Fickle

.PHONY: status status-spot-fleet status-instance status-route53 status-volume status-eni clean start

status: status-spot-fleet status-instance status-route53 status-volume status-eni

status-spot-fleet:
	@result=$$(aws ec2 describe-spot-fleet-requests \
		--query "SpotFleetRequestConfigs[?SpotFleetRequestState!='cancelled'].{ID:SpotFleetRequestId,State:SpotFleetRequestState,Capacity:SpotFleetRequestConfig.FulfilledCapacity}" \
		--output table --region $(REGION) 2>/dev/null); \
	if [ -n "$$result" ] && [ "$$result" != "None" ] && [ "$$result" != "[]" ]; then \
		echo "$$result"; \
	else \
		echo "No active spot fleet requests found"; \
	fi

status-instance:
	@result=$$(aws ec2 describe-instances \
		--query "Reservations[*].Instances[*].{ID:InstanceId,State:State.Name,IP:PublicIpAddress,Name:Tags[?Key=='Name'].Value|[0]}" \
		--output table --region $(REGION) 2>/dev/null); \
	if [ -n "$$result" ] && [ "$$result" != "None" ] && [ "$$result" != "[]" ]; then \
		echo "$$result"; \
	else \
		echo "No instances found"; \
	fi

status-route53:
	@result=$$(aws route53 list-hosted-zones \
		--query "HostedZones[*].{ID:Id,Name:Name,RecordCount:ResourceRecordSetCount}" \
		--output table 2>/dev/null); \
	if [ -n "$$result" ] && [ "$$result" != "None" ] && [ "$$result" != "[]" ]; then \
		echo "$$result"; \
	else \
		echo "No hosted zones found"; \
	fi

status-volume:
	@result=$$(aws ec2 describe-volumes \
		--query "Volumes[*].{ID:VolumeId,State:State,AttachedTo:Attachments[0].InstanceId,Size:Size}" \
		--output table --region $(REGION) 2>/dev/null); \
	if [ -n "$$result" ] && [ "$$result" != "None" ] && [ "$$result" != "[]" ]; then \
		echo "$$result"; \
	else \
		echo "No volumes found"; \
	fi

status-eni:
	@result=$$(aws ec2 describe-network-interfaces \
		--query "NetworkInterfaces[*].{ID:NetworkInterfaceId,Status:Status,IP:PrivateIpAddress,AttachedTo:Attachment.InstanceId,Type:InterfaceType}" \
		--output table --region $(REGION) 2>/dev/null); \
	if [ -n "$$result" ] && [ "$$result" != "None" ] && [ "$$result" != "[]" ]; then \
		echo "$$result"; \
	else \
		echo "No network interfaces found"; \
	fi

clean:
	@./cleanup.sh

start:
	@./spinup.sh
