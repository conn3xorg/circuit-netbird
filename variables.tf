variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file, jump_hosts or os."

  validation {
    condition     = alltrue([for h in var.hosts : contains(["debian", "ubuntu", "rocky", "almalinux", "rhel", "fedora"], try(h.os, "debian"))])
    error_message = "A host object's os must be one of debian, ubuntu, rocky, almalinux, rhel or fedora. CentOS Linux reached end of life on 30 June 2024: use Rocky Linux."
  }
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "netbird_version" {
  type        = string
  default     = "0.82.0"
  description = "NetBird client release to install from NetBird's repository, such as \"0.82.0\"."

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.netbird_version))
    error_message = "netbird_version is a release number such as \"0.82.0\"."
  }
}

variable "management_url" {
  type        = string
  default     = "https://api.netbird.io:443"
  description = "Management server the hosts join: NetBird's own, or your self-hosted server's address, such as \"https://netbird.example.com:443\"."

  validation {
    condition     = can(regex("^https?://[A-Za-z0-9.-]+(:[0-9]{1,5})?$", var.management_url))
    error_message = "management_url is a URL with a scheme, a host and an optional port, such as \"https://netbird.example.com:443\"."
  }
}

variable "join" {
  type        = bool
  default     = true
  description = "Join the hosts to the network with setup_key. When false, the circuit installs NetBird and leaves the hosts as they are."
}

variable "setup_key" {
  type        = string
  default     = null
  ephemeral   = true
  sensitive   = true
  description = "NetBird setup key the hosts join with, such as A1B2C3D4-.... Required when join is true."

  validation {
    condition     = !var.join || can(regex("^[A-Za-z0-9-]{20,}$", var.setup_key))
    error_message = "Set setup_key to a NetBird setup key, or set join = false to install NetBird without joining."
  }
}

variable "hostname" {
  type        = string
  default     = null
  description = "Name for the peer in the network. When null, NetBird uses the host's name. Meant for a single host: every host gets the same name. Used only when joining."

  validation {
    condition     = var.hostname == null || can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$", coalesce(var.hostname, "-")))
    error_message = "hostname must be letters, digits and -, such as \"nas\", up to 63 characters."
  }
}

variable "extra_args" {
  type        = list(string)
  default     = []
  description = "More flags for netbird up, such as [\"--disable-dns\"]. Used only when joining."

  validation {
    condition     = alltrue([for a in var.extra_args : can(regex("^--[a-z0-9-]+(=[A-Za-z0-9_.,:/@+=-]*)?$", a))])
    error_message = "Each of extra_args must be one flag such as \"--disable-dns\" or \"--wireguard-port=51821\", without spaces or quotes."
  }
}
