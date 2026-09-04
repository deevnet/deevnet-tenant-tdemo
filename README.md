# tdemo

The `tdemo` tenant, as code. This repository **is** the tenant: its overlay
network, its workloads and its DNS records are all declared here, and it can be
rebuilt from scratch against the substrate without a substrate commit
([ADR-0006](https://github.com/deevnet/deevnet-docs)).

| | |
|---|---|
| Index | 1 (allocated in the factory's `TENANTS.md`) |
| Subnet | `10.20.129.0/24`, gateway `10.20.129.1` |
| Zone | `tdemo.dvntm.deevnet.net` |
| Module | `tenant-module-v1.0.0` |

## What the substrate issues, and what you author

Onboarding is a substrate act, done once. Three things arrive from it and are
**not** authored here:

| Issued | Arrives as | Re-issue with |
|---|---|---|
| Fabric attachment | `fabric.auto.tfvars` | `make tenant-attachment TENANT=<this repo>` in the factory |
| TSIG key | `TF_VAR_tsig_key_secret` | read from the inventory vault |
| Tenant index | the value in `main.tf` | allocated in `TENANTS.md` |

Everything else is yours. Adding a record, changing one, rebuilding, destroying
— all `terraform apply` here, touching no substrate repository.

## Running it

```bash
export TF_VAR_tsig_key_secret=$(ansible-vault view \
  ../ansible-inventory-deevnet/dvntm/group_vars/all/vault.yml \
  | yq -r .vault_tenant_tsig_keys.tdemo)

make init      # fetches the tagged module - needs GitHub and your ssh-agent
make plan
make apply
```

Proxmox credentials are rendered from the inventory vault by the targets
themselves; nothing is stored here.

## The module is pinned by tag

`terraform init` vendors the module into `.terraform/modules/` and neither
`plan` nor `apply` re-fetches it. **Moving to a newer module tag requires an
explicit `terraform init -upgrade`** — so a repository that never re-inits stays
on its old module indefinitely, quietly.

Provider pins are committed (`.terraform.lock.hcl`). A module pinned by tag with
providers left to float is half a pin.

## State

State is **not** in this repository. It lives in the substrate's state store,
which is offered rather than mandated
([ADR-0007](https://github.com/deevnet/deevnet-docs)) — a tenant may decline it
and carry its own custody instead.

Whichever applies: state is never hand-edited, and must not come to contain a
secret. Prefer resources whose values can be re-derived over ones that generate
a credential, because a generated credential lives in state permanently.

Losing state costs a rebuild, not a loss — nothing here is irreplaceable, which
is the same property that makes *rebuilt from code, not from a backup* true.
