
hostname  = ARGV[0] || "localhost"
port      = ARGV[1] || 4000

require './daemon.rb'


msg = [Time.now.to_i, 
  "Application", 
  "Name", 
  "Message.", 
  File.open('sample.jpg', 'rb').read
  ]


client = MPPDaemon::Client.new(hostname, port)
success = client.send(msg)
puts "Succeeded? #{success}"
