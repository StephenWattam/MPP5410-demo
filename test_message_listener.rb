
hostname  = ARGV[0] || "localhost"
port      = ARGV[1] || 4000

require 'socket'
require 'base64'


msg = ["#{Time.now.to_i}\n", Base64.encode64("Application"), Base64.encode64("Name"), Base64.encode64("Message.")].join


s = TCPSocket.new(hostname, port.to_i)
s.write(msg)
puts "SENT: #{msg}"
puts "RECEIVED: #{s.read}"
s.close
