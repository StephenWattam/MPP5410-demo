


require './daemon.rb'
require './lib/mpp5410.rb'
require 'RMagick'


printer_file  = ARGV[0]   || '/dev/ttyUSB0'
port_low      = ARGV[1]   || 4000
port_high     = ARGV[2]   || 4010



# Open the mpp
mpp = MPP5410::MPP5410Device.open(printer_file, :hardware)
# # Close mpp on exit
at_exit do
  mpp.close
end


processor = lambda{|hash|
  puts "--> received #{hash}"
  # img = Magick::Image.from_blob(hash[:image])[0]
  # img[0].display
  
  # Top line
  imagedata = ["\xf0"] * (mpp.bytes_per_image_line(8, :single)*2)
  # mpp.plot_bitfield(imagedata, 8, :single)
  # 
  # 
  # mpp.puts "Service: #{hash[:app]}"
  # mpp.puts "Time: #{Time.at(hash[:time].to_i)}"
  # mpp.puts "Name: #{hash[:name]}"
  # mpp.puts "Message: #{hash[:msg]}"
  # # mpp.plot_image(img, 8, :single, 0, true)
  # 
  # # Bottom line 
  # imagedata = ["\xf0"]*mpp.bytes_per_image_line(8, :single)
  # mpp.plot_bitfield(imagedata, 8, :single)

  # # Feed above housing
  # mpp.print_and_feed_paper
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

