# A tenant declares very little: its name, what its workloads run on, and the
# keys that reach them.

variable "tenant_name" {
  type        = string
  default     = "tdemo"
  description = <<-EOT
    The name the substrate admitted. 1-8 lowercase alphanumerics starting with
    a letter: it is the SDN zone id, a DNS label and a state-store user.

    A copy of this repository changes this and nothing else.
  EOT
}

variable "vm_cores" {
  type        = number
  default     = 2
  description = "Cores for the workload."
}

variable "vm_memory_mb" {
  type        = number
  default     = 2048
  description = "Memory for the workload, in MB."
}

variable "ssh_keys" {
  type        = list(string)
  default     = []
  description = "Public keys for the workload's cloud-init account. Public halves only."
}
