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

1. **Your development environment:** a macOS, Linux or Windows computer with Wi-Fi, and Terraform.
   The provider and two scripts come from the tenant downloads site. Once you are on `DVNTM-TD`, in
   a working directory (your tenant repository is cloned inside it, below):

   ```bash
   curl -fsSLk -O https://downloads.mobile.deevnet.net/deevnet-root-ca.pem
   openssl x509 -in deevnet-root-ca.pem -noout -fingerprint -sha256    # check it against Before You Start
   curl -fsSL --cacert deevnet-root-ca.pem -O https://downloads.mobile.deevnet.net/scripts/install-provider.sh
   curl -fsSL --cacert deevnet-root-ca.pem -O https://downloads.mobile.deevnet.net/scripts/tenant-check.sh
   bash install-provider.sh
   ```

   On Windows, in PowerShell (or under WSL2, the lines above as they are):

   ```powershell
   curl.exe -fsSLk -O https://downloads.mobile.deevnet.net/deevnet-root-ca.pem
   $c = [Security.Cryptography.X509Certificates.X509Certificate2]::new("$PWD\deevnet-root-ca.pem")
   [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($c.RawData))   # check it
   curl.exe -fsSL --ssl-revoke-best-effort --cacert deevnet-root-ca.pem -O https://downloads.mobile.deevnet.net/scripts/install-provider.ps1
   curl.exe -fsSL --ssl-revoke-best-effort --cacert deevnet-root-ca.pem -O https://downloads.mobile.deevnet.net/scripts/tenant-check.ps1
   powershell -ExecutionPolicy Bypass -File install-provider.ps1
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
Deevnet Root CA in the repository, where every command below expects it:

```bash
bash ../tenant-check.sh --write-ca .
```

**On Windows**, `tenant.ps1` does what the Makefile does, with the same guards, and needs no make,
bash or Python. Every `make <target>` below is `.\tenant.ps1 <target>`; `NAME=x` is `-Name x` and
`AUTO=1` is `-Auto`. If PowerShell refuses to run scripts, prefix each one with
`powershell -ExecutionPolicy Bypass -File`.

```powershell
.\tenant.ps1 new -Name bench1
powershell -ExecutionPolicy Bypass -File ..\tenant-check.ps1 -WriteCa .
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

```powershell
Add-Content terraform.tfvars "ssh_keys = [`"$((Get-Content ~\.ssh\id_ed25519.pub).Trim())`"]"
```

## First apply

```bash
export DEEVNET_API_TOKEN=<your enrollment token>
make init
make apply
export DEEVNET_API_TOKEN=$(terraform output -raw api_token)   # from now on
```

```powershell
$env:DEEVNET_API_TOKEN = '<your enrollment token>'
.\tenant.ps1 init
.\tenant.ps1 apply
$env:DEEVNET_API_TOKEN = terraform output -raw api_token        # from now on
```

The first apply spends the enrollment token and receives your tenant's own. Put the last line in
whatever sets up a shell for this project.

**Your state now holds every credential your tenant was issued**, and for most of them it is the
only copy. Never commit `terraform.tfstate`. Next step: move it into the state store.

## Keep your state in the store

```bash
make state-backend          # Windows: .\tenant.ps1 state-backend
```

writes `backend.tf` (commit it) and `.backend.env` (the state store's credentials: secret,
gitignored, readable by you alone, keep a copy somewhere safe), then moves your local state into
the store over TLS. Both `make` and `tenant.ps1` read the same `.backend.env`. From
then on the Makefile loads `.backend.env` for you. On another computer, clone the repository and copy
`.backend.env` and `deevnet-root-ca.pem` in; `make init` does the rest.

The store is offered, not required. A tenant that keeps its own custody skips this step.

## Use it

| To | Run |
|---|---|
| Flash a device | `terraform output -json flash`: its Wi-Fi SSID and key, its broker user, password and topics |
| Log in to the backend workload | `terraform output backend`: the address and the exact `ssh` line |
| Run your app anywhere | `terraform output -raw kit_env > kit.env`: every endpoint, token and login it needs, by name |

In Windows PowerShell 5.1, `>` writes UTF-16, which nothing reading `kit.env` expects. Let `cmd`
redirect it, byte for byte: `cmd /c "terraform output -raw kit_env > kit.env"`.

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
| `tenant.ps1` | the Makefile for Windows PowerShell: the same targets and guards |

## When something is wrong

- **`backend.tf belongs to another tenant`**: you copied without `make new`.
- **`DEEVNET_API_TOKEN is not set`**: the export after the first apply is missing.
- **`x509: certificate signed by unknown authority`**: `deevnet-root-ca.pem` is missing or old;
  `tenant-check.sh --write-ca .` (or `tenant-check.ps1 -WriteCa .`) again.
- **`$'\r': command not found` or `missing separator`** under WSL2 or Git Bash: the repository was
  checked out with Windows line endings. Clone inside WSL, or `git add --renormalize .` after
  pulling the `.gitattributes`.
- **`Backend configuration changed`** after the site root's rename (CHG-0031): `terraform init
  -reconfigure`, once. The state does not move; only the CA file's name in `backend.tf` did.
- **Lost the state, or `.backend.env`**: the tenant guide's Recovery section. The operator can
  restore some of it; what only your state held has to be reissued.
