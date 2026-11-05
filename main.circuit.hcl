# Facts give each host's distribution, which picks NetBird's apt or rpm
# repository.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }

  lifecycle {
    postcondition {
      condition     = contains(["debian", "ubuntu", "rocky", "almalinux", "rhel", "fedora"], self.os_id)
      error_message = "Host ${each.key} runs ${self.os_id}. This circuit supports Debian, Ubuntu, Rocky Linux, AlmaLinux, RHEL and Fedora. CentOS Linux reached end of life on 30 June 2024: use Rocky Linux."
    }
    postcondition {
      condition     = try(each.value.os, self.os_id) == self.os_id
      error_message = "Host ${each.key} is ${self.os_id}, not the ${try(each.value.os, "")} its os says."
    }
  }
}

locals {
  # A host object's os stands in for the facts of a host created in the
  # same plan, which can't be read until it exists.
  os  = { for name, h in var.hosts : name => try(h.os, data.conn3x_host.facts[name].os_id) }
  deb = { for name, o in local.os : name => contains(["debian", "ubuntu"], o) }

  key_file = "/etc/netbird/setup-key"

  up = join(" ", compact([
    "netbird up --setup-key-file ${local.key_file} --management-url '${var.management_url}'",
    var.hostname == null ? "" : "--hostname '${var.hostname}'",
    join(" ", var.extra_args),
  ]))

  # Logged in, whether or not the tunnel is up this second.
  logged_in = "netbird status --json | grep -Eq '\"daemonStatus\": *\"(Connected|Connecting)\"'"
}

circuit "netbird" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # NetBird signs its apt and rpm repositories with different keys, both in
  # files: EFE3 7DF0 47DF 7CCD F1FC 54FA 83F7 9AD0 2977 8355 for apt and
  # AA9C 09AA 9DEA 2F58 112B 40DF DFFE AB2F D267 A61F for rpm. Neither
  # expires.
  step "repo" {
    repository {
      name       = "netbird"
      url        = local.deb[each.key] ? "https://pkgs.netbird.io/debian" : "https://pkgs.netbird.io/yum/"
      key        = file("${path.module}/files/${local.deb[each.key] ? "netbird-deb.asc" : "netbird-rpm.asc"}")
      suites     = local.deb[each.key] ? ["stable"] : null
      components = ["main"]
    }
  }

  # The package installs netbird.service and starts it. An upgrade restarts
  # it, and the client reconnects with the identity it already has.
  step "package" {
    package {
      name    = "netbird"
      version = var.netbird_version
    }
  }

  step "running" {
    service {
      name    = "netbird"
      state   = "started"
      enabled = true
    }
  }

  # Setting join = false removes the step, and with it the key.
  step "setup_key" {
    for_each = var.join ? toset(["key"]) : toset([])
    file {
      path       = local.key_file
      content_wo = var.setup_key
      on_remove  = "delete"
    }
  }

  # Joins the network, unless the client is already logged in.
  step "up" {
    for_each = var.join ? toset(["key"]) : toset([])
    command {
      command = local.up
      unless  = local.logged_in
    }
  }
}
