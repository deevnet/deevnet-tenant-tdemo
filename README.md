# tdemo

**The reference tenant**, and a starting point for your own. This repository declares a whole
small Deevnet tenant: a Wi-Fi key and a device, a backend workload you can log in to, and the
broker accounts between them. It is the tenant guide's walkthrough as one configuration. It is
also a live tenant, `tdemo`, so every line here is applied, not just shown.

Everything goes through one provider, `deevnet/deevnet`, and one credential, your tenant's API
token. The Deevnet docs' tenant guide explains each service; this README is the order to do things
in.

## Before you start

The tenant guide's *Before You Start* has the detail; in short:

1. **Your development environment:** a macOS or Linux computer with Wi-Fi, and Terraform. The
   provider and two scripts come from the tenant downloads site. Once you are on `DVNTM-TD`, in a
   working directory (your tenant repository is cloned inside it, below):

   ```bash
   curl -fsSLk -o site-ca.pem https://downloads.mobile.deevnet.net:8443/site-ca.pem
   openssl x509 -in site-ca.pem -noout -fingerprint -sha256    # check it against Before You Start
   curl -fsSL --cacert site-ca.pem -O https://downloads.mobile.deevnet.net:8443/scripts/install-provider.sh
   curl -fsSL --cacert site-ca.pem -O https://downloads.mobile.deevnet.net:8443/scripts/tenant-check.sh
   bash install-provider.sh
   ```
2. **Admitted.** The operator admits your tenant name and hands you a single-use **enrollment
   token** and your **`DVNTM-TD` Wi-Fi key**. Those two are secret; the API's address and
   certificate are public.
3. **On `DVNTM-TD`**, with that key. Tenants connect over Wi-Fi only. It reaches the API, the
   state store, the broker, the log store, Grafana and the tenant downloads.

## Make it yours

```bash
git clone https://github.com/deevnet/deevnet-tenant-tdemo deevnet-tenant-bench1
cd deevnet-tenant-bench1 && rm -rf .git && git init    # your own history, not tdemo's
make new NAME=bench1          # exactly the name you were admitted with
```

`make new` writes your name into `terraform.tfvars` and removes `backend.tf`, which points at
tdemo's state. Nothing else in the repository names a tenant. Then check your computer and put the
site CA in the repository, where every command below expects it:

```bash
bash ../tenant-check.sh --write-ca .
```

Then decide what you want, in `terraform.tfvars`:

```hcl
tenant_name      = "bench1"
devices          = ["pico-1"]                        # one broker account and registry entry each
backend_workload = true                              # false: run your backend on your computer
ssh_keys         = ["ssh-ed25519 AAAA... you@computer"] # a LIST, even of one; the PUBLIC half only
```

The quickest way to add your key, brackets and all:

```bash
echo "ssh_keys = [\"$(cat ~/.ssh/id_ed25519.pub)\"]" >> terraform.tfvars
```

## First apply

```bash
export DEEVNET_API_TOKEN=<your enrollment token>
make init
make apply
export DEEVNET_API_TOKEN=$(terraform output -raw api_token)   # from now on
```

The first apply spends the enrollment token and receives your tenant's own. Put the last line in
whatever sets up a shell for this project.

**Your state now holds every credential your tenant was issued**, and for most of them it is the
only copy. Never commit `terraform.tfstate`. Next step: move it into the state store.

## Keep your state in the store

```bash
make state-backend
```

writes `backend.tf` (commit it) and `.backend.env` (the state store's credentials: secret,
gitignored, keep a copy somewhere safe), then moves your local state into the store over TLS. From
then on the Makefile loads `.backend.env` for you. On another computer, clone the repository and copy
`.backend.env` and `site-ca.pem` in; `make init` does the rest.

The store is offered, not required. A tenant that keeps its own custody skips this step.

## Use it

| To | Run |
|---|---|
| Flash a device | `terraform output -json flash`: its Wi-Fi SSID and key, its broker user, password and topics |
| Log in to the backend workload | `terraform output backend`: the address and the exact `ssh` line |
| Run your app anywhere | `terraform output -raw kit_env > kit.env`: every endpoint, token and login it needs, by name |

Your app reads its settings from `kit.env` and nothing else, so it runs the same on your computer,
on the workload, and, with a Pi's own `kit.env`, on a Pi of your own (the tenant guide's
"Convert a Tenant to a Pi Image").

**Keys are written when the workload is built.** To change `ssh_keys` later,
`terraform apply -replace='deevnet_workload.backend[0]'`, which rebuilds the VM.

## What is in here

| File | |
|---|---|
| `main.tf` | the tenant, the device side and the backend |
| `variables.tf` | the name, the devices, the workload switch, SSH keys |
| `terraform.tfvars` | this tenant's values: the only file that names it |
| `outputs.tf` | `flash`, `backend`, `kit_env`, and the credentials the substrate issued |
| `backend.tf` | where this tenant's state lives, written by `make state-backend` |
| `Makefile` | the endpoint, the CA, the guards above, and `state-backend` |

## When something is wrong

- **`backend.tf belongs to another tenant`**: you copied without `make new`.
- **`DEEVNET_API_TOKEN is not set`**: the export after the first apply is missing.
- **`x509: certificate signed by unknown authority`**: `site-ca.pem` is missing or old;
  `tenant-check.sh --write-ca .` again.
- **Lost the state, or `.backend.env`**: the tenant guide's Recovery section. The operator can
  restore some of it; what only your state held has to be reissued.
