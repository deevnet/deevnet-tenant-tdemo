# tdemo

**The reference tenant.** Copy this repository to create a tenant, change the
name, and apply. It is a working tenant, not a sample: the rebuild drill applies
it and destroys it again.

A tenant is its own repository ([ADR-0006][adr6]), and everything in it goes
through one provider, `deevnet/deevnet` ([ADR-0015][adr15]).

[adr6]: https://deevnet.github.io/deevnet-docs/docs/architecture/decisions/0006-tenant-code-boundary/
[adr15]: https://deevnet.github.io/deevnet-docs/docs/architecture/decisions/0015-tenant-onboarding-through-api/
[adr7]: https://deevnet.github.io/deevnet-docs/docs/architecture/decisions/0007-terraform-state-custody/
[adr4]: https://deevnet.github.io/deevnet-docs/docs/architecture/decisions/0004-tenant-dns-publication/

## What a tenant holds

One credential: its Deevnet API token.

- **No index.** The API allocates it, and everything numbered - VNIs, subnet,
  gateway, reverse zone, each workload's VMID, MAC and address - derives from it.
- **No Proxmox credential.** The API builds the tenant's network and its VMs.
- **No vault access.** The TSIG key and the state-store credential come back
  from the API into this state, which is their authoritative copy.

## Creating a tenant from this

1. **Ask the substrate to admit a name.** The operator runs the admission and
   sends back a **single-use enrollment token**, age-encrypted into your
   repository, with the API's address and its CA certificate.
2. **Copy this repository** and set `tenant_name` (in `terraform.tfvars` or by
   editing the default). Change nothing else.
3. **Apply with the enrollment token:**

   ```bash
   export DEEVNET_API_TOKEN=<enrollment token>
   make init
   make apply
   ```

   The first apply spends the enrollment token and receives the tenant's own.

4. **Use the tenant's own token from then on:**

   ```bash
   export DEEVNET_API_TOKEN=$(terraform output -raw api_token)
   ```

5. **Move state into the store, if you want it** ([ADR-0007][adr7]):
   `make state-backend` prints the block and the credentials, then
   `terraform init -migrate-state`. A tenant that keeps its own custody skips
   this; the store is offered, not required.

## What is in here

| File | |
|---|---|
| `main.tf` | the tenant, one workload, and one published name |
| `variables.tf` | the name, the workload's sizing, SSH keys |
| `outputs.tf` | the subnet and names, and the credentials the substrate issued |

## Recovering after a substrate rebuild

Apply again. If the API lost its registry, this state still proves who the
tenant is and what it held: the same index comes back, with the same keys, and
the plan is empty. Only if another tenant took the index in the meantime is a
new one issued, and then the tenant's network and workloads are rebuilt on it
(ADR-0015 §5).

## Publishing names yourself

The workload's own name and anything declared here are published by the API.
The tenant's TSIG key is still issued, so a tenant that would rather write
records over RFC 2136 can: `terraform output -json dns_publication` has the
server, zones and key ([ADR-0004][adr4]).

## Until the provider is published

The provider is not in the public registry yet, so `terraform init` needs it
locally. Build it and put it where Terraform looks:

```bash
git clone git@github.com:deevnet/terraform-provider-deevnet.git
cd terraform-provider-deevnet && make build
V=0.1.0; OS_ARCH=linux_amd64
D=~/.terraform.d/plugins/registry.terraform.io/deevnet/deevnet/$V/$OS_ARCH
mkdir -p $D && cp terraform-provider-deevnet $D/
```

The site's provider mirror replaces this step, and an offline `terraform init`
is what that mirror is for (ADR-0012 §7).
