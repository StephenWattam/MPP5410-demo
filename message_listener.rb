


require './daemon.rb'
require './lib/mpp5410.rb'
require 'RMagick'


printer_file  = ARGV[0]   || '/dev/ttyUSB0'
port_low      = ARGV[1]   || 4000
port_high     = ARGV[2]   || 4010



# Open the mpp
# mpp = MPP5410::MPP5410Device.open(printer_file, :hardware)
# # Close mpp on exit
# at_exit do
#   mpp.close
# end


processor = lambda{|hash|
  # img = Magick::Image.from_blob(hash[:image])
  # img[0].display
  puts "Received a tasty little message: #{hash[:name]} #{hash[:msg]}"
  # puts "===> #{img}"
}




# Check le port
raise "High port is below low port" if port_high < port_low
puts "Listening on ports #{port_low} to #{port_high}..."
d = MPPDaemon::Server.new((port_low .. port_high).to_a, [:time, :app, :name, :msg, :image], processor, false)
begin
  d.listen
rescue Exception => e
  $stderr.puts "Exception caught: #{e}"
  $stderr.puts e.backtrace.join("\n")
end
d.close
puts "Done."

