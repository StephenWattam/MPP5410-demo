
hostname  = ARGV[0] || "localhost"
port      = ARGV[1] || 4000

require './daemon.rb'


msg = [
  Time.now.to_i, 
  "Application", 
  "Name", 
  "Message.", 
  File.open('sample.jpg', 'rb').read
  ]


10.times{
  success = MPPDaemon::Client.send(hostname, port, msg)
  puts "Succeeded? #{success}"
}
