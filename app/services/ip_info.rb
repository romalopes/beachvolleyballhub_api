# frozen_string_literal: true

require "socket"

# Read-only helpers for the host's IP addresses.
#
# Zeitwerk maps this file to the constant `IpInfo`, so the module name must stay
# exactly that. Nothing runs at load time: eager loading (production) merely
# requires this file and must not print output, raise, or pollute Object with
# top-level methods.
#
# Interface names differ per platform (en0 on macOS, eth0 in a container), so
# `local_ip` scans every interface instead of assuming one.
module IpInfo
  module_function

  # First non-loopback IPv4 address bound to a local interface, or nil when the
  # host has none (e.g. a build step that runs without networking).
  def local_ip
    Socket.getifaddrs.each do |ifaddr|
      next unless ifaddr.addr&.ipv4?
      next if ifaddr.addr.ipv4_loopback?

      ip = ifaddr.addr.ip_address
      return ip if ip.present?
    end

    nil
  rescue StandardError
    nil
  end

  # IPv4 address resolved for this host's own name, or nil when it cannot be
  # resolved. Containers often have no resolvable self-hostname, so this is
  # strictly best-effort.
  def network_ip
    Socket.getaddrinfo(Socket.gethostname, nil, Socket::AF_INET, Socket::SOCK_DGRAM)
          .first
          &.dig(3, "IPAddress")
  rescue StandardError
    nil
  end

  # Convenience view for logging and diagnostics.
  def summary
    { local_ip: local_ip, network_ip: network_ip }
  end
end
