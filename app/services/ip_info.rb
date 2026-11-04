# ip_addresses.rb

require 'socket'

def get_local_ip
  ip_address = Socket.getifaddrs.find { |addr| addr.name == 'en0' && addr.addr.ipv4? }
  ip_address&.addr&.ip_address
end

def get_network_ip
  hostname = Socket.gethostname
  Socket.getaddrinfo(hostname, nil, Socket::AF_INET, Socket::SOCK_DGRAM).first[3]['IPAddress']
end

puts "Local IP: #{get_local_ip}"
puts "Network IP: #{get_network_ip}"
