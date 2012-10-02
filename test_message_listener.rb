
hostname  = ARGV[0] || "localhost"
port      = ARGV[1] || 4000

require 'socket'
require 'base64'


msg = [Time.now.to_i, 
  "Application", 
  "Name", 
  "Message.", 
  File.open('sample.jpg', 'rb').read
  ]


msg.map!{|x| Base64.strict_encode64(x.to_s)}

msg = msg.join("\n") + "\n"

s = TCPSocket.new(hostname, port.to_i)
s.write(msg)
puts "SENT: #{msg}"
puts "RECEIVED: #{s.read}"
s.close
