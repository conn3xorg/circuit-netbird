variable "port" {
  type    = number
  default = 2222
}

# Leave both unset to install NetBird without joining. To join, pass
# -var join=true and the key in TF_VAR_setup_key.
variable "join" {
  type    = bool
  default = false
}

variable "setup_key" {
  type      = string
  default   = null
  ephemeral = true
}

# CI points this at its own self-hosted server.
variable "management_url" {
  type    = string
  default = "https://api.netbird.io:443"
}

# CI applies an older release first, then this one, to test the upgrade.
variable "netbird_version" {
  type    = string
  default = "0.82.0"
}

module "netbird" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  netbird_version = var.netbird_version
  management_url  = var.management_url
  join            = var.join
  setup_key       = var.setup_key
  hostname        = "conn3x-example"
}
