variable "tenant_name" {
  type        = string
  description = <<-EOT
    Exactly the name you were admitted with: 1-8 lowercase alphanumerics
    starting with a letter. Set in terraform.tfvars (`make new NAME=...`).
  EOT
}

variable "devices" {
  type        = list(string)
  default     = ["pico-1"]
  description = "Your devices, by name. Each gets a registry entry and a broker account."
}

variable "backend_workload" {
  type        = bool
  default     = true
  description = "Run the backend on a Deevnet VM. False keeps it on your computer or a Pi."
}

variable "ssh_keys" {
  type        = list(string)
  default     = []
  description = <<-EOT
    PUBLIC keys that may log in to the backend workload, e.g.
    [file("~/.ssh/id_ed25519.pub")]. The private key stays on your computer.
    Keys are written when the workload is built; to change them later,
    `terraform apply -replace='deevnet_workload.backend[0]'`.
  EOT
}
