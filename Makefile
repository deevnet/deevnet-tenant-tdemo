# A Deevnet tenant. `make help` for the targets; README.md for the steps.
#
# A tenant holds one credential: its Deevnet API token. There is no vault to
# read, no Proxmox credential to render, and no index to allocate.
# Plain recipes, one shell per line: macOS ships GNU make 3.81, which has no
# .ONESHELL. /bin/bash is on macOS and Linux alike.
SHELL := /bin/bash

# The API and the certificate it is served with. deevnet-root-ca.pem comes from
# tenant-check.sh --write-ca . (or the operator), and is gitignored.
export DEEVNET_API_ENDPOINT ?= https://api.mobile.deevnet.net:8080
export DEEVNET_API_CACERT   ?= $(CURDIR)/deevnet-root-ca.pem

# The state store's credentials, once `make state-backend` has written them.
# Secret, gitignored, and needed by every command once state lives in the store.
-include .backend.env
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

# This tenant's name, from terraform.tfvars.
TENANT := $(shell sed -n 's/^tenant_name *= *"\(.*\)"/\1/p' terraform.tfvars 2>/dev/null)

TF_APPROVE := $(if $(AUTO),-auto-approve,)

.PHONY: help new require-token check-backend init plan apply destroy state-backend fmt validate

help:
	@echo "Deevnet tenant: $(or $(TENANT),<none - run make new NAME=...>)"
	@echo
	@echo "  new NAME=x     make this copy your tenant x (rewrites terraform.tfvars,"
	@echo "                 removes the backend.tf of the tenant it was copied from)"
	@echo "  init           terraform init"
	@echo "  plan           terraform plan"
	@echo "  apply          terraform apply    (AUTO=1 to skip approval)"
	@echo "  destroy        terraform destroy  (AUTO=1 to skip approval)"
	@echo "  state-backend  move state into the state store: writes backend.tf and"
	@echo "                 .backend.env from this tenant's outputs, then migrates"
	@echo "  validate       fmt check + validate"
	@echo
	@echo "Needs DEEVNET_API_TOKEN: the enrollment token on the first apply, then"
	@echo "  export DEEVNET_API_TOKEN=\$$(terraform output -raw api_token)"

# A copy of someone else's tenant becomes yours. The backend.tf it came with
# points at the other tenant's state, so it goes; yours is written by
# state-backend after your first apply.
new:
	@if [[ -z "$(NAME)" ]]; then echo "make new NAME=<the name you were admitted with>" >&2; exit 2; fi
	@if [[ ! "$(NAME)" =~ ^[a-z][a-z0-9]{0,7}$$ ]]; then \
		echo "'$(NAME)' is not a tenant name: 1-8 lowercase letters or digits, starting with a letter" >&2; exit 2; fi
	@if [[ -s terraform.tfstate || -f .backend.env ]]; then \
		echo "This directory already holds a tenant's state; make new is for a fresh copy." >&2; exit 2; fi
	@printf '# This tenant. `make new NAME=<name>` rewrites this file for a copy.\ntenant_name = "%s"\n' "$(NAME)" > terraform.tfvars
	@rm -rf backend.tf .terraform .terraform.lock.hcl
	@echo "This is now tenant $(NAME). Next: make init, then make apply with your enrollment token."

# The one credential. It is never stored here: a tenant token belongs in the
# state, and the enrollment token is single use.
require-token:
	@if [[ -z "$${DEEVNET_API_TOKEN:-}" ]]; then \
		echo "DEEVNET_API_TOKEN is not set." >&2; \
		echo "  First apply:  the enrollment token from your admission." >&2; \
		echo "  After that:   export DEEVNET_API_TOKEN=\$$(terraform output -raw api_token)" >&2; \
		exit 2; fi

# A backend.tf that names another tenant's state is the classic copy mistake:
# init would try to read that tenant's state with credentials you don't have.
check-backend:
	@if [[ -z "$(TENANT)" ]]; then echo "No tenant_name in terraform.tfvars: make new NAME=<name>" >&2; exit 2; fi
	@if [[ -f backend.tf ]] && ! grep -q 'tenants/$(TENANT)/' backend.tf; then \
		echo "backend.tf belongs to another tenant, not $(TENANT)." >&2; \
		echo "  A fresh copy: make new NAME=$(TENANT)" >&2; \
		exit 2; fi
	@if [[ -f backend.tf && ! -f .backend.env ]]; then \
		echo "backend.tf is here but .backend.env is not: copy .backend.env from the machine" >&2; \
		echo "that ran make state-backend (it holds the state store's credentials)." >&2; \
		exit 2; fi

init: check-backend
	terraform init

plan: check-backend require-token
	terraform plan

apply: check-backend require-token
	terraform apply $(TF_APPROVE)

destroy: check-backend require-token
	terraform destroy $(TF_APPROVE)

# The state store is offered, not mandated (ADR-0007). Its credentials are
# outputs of the tenant, so it is set up after the first apply: backend.tf
# (not secret - commit it in your own repository) and .backend.env (secret,
# gitignored), then the local state moves in.
state-backend: check-backend
	@if [[ -f backend.tf ]]; then echo "backend.tf already exists; state is already in the store." >&2; exit 2; fi
	terraform output -json state_backend | python3 scripts/state-backend.py
	set -a; . ./.backend.env; set +a; terraform init -migrate-state
	@echo "State is in the store. Commit backend.tf; keep .backend.env safe - it is the key to your state."

fmt:
	terraform fmt -recursive

validate:
	terraform fmt -check -recursive
	terraform validate
