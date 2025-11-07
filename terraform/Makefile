.PHONY: infra server dns all plan clean

infra:
	cd infra && terraform apply -auto-approve

server: infra
	cd server && terraform apply -auto-approve

dns: server
	cd dns && terraform apply -auto-approve

all: dns

plan:
	cd infra && terraform plan
	cd server && terraform plan
	cd dns && terraform plan

clean:
	cd dns && terraform destroy -auto-approve || true
	cd server && terraform destroy -auto-approve || true
    # No reason to destroy infra
    # cd infra && terraform destroy -auto-approve || true
