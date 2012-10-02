# Message daemon listener for the mpp5410 message system
#
# Accepts base64-encoded unicode strings of the format:
# time
# stuff
require 'socket'
require 'base64'
require 'timeout'
require 'thread'

module MPPDaemon 
  CLIENT_TIMEOUT = 5
  NACK  = 'NACK'
  ACK   = 'ACK'
  MESSAGE_FIELDS = [:time, :app, :name, :msg]

  class Server
    def initialize(ports, msg_fields = MESSAGE_FIELDS, op = lambda{|x| puts "RECEIVED: #{x}"}, thread = true)
      @sockets      = ports.map{|x| TCPServer.new(x.to_i) }
      @msg_fields   = msg_fields
      @op           = op
      @thread       = thread 
    end

    def listen
      # Make the sockets listen
      @sockets.each{|s| s.listen(1) }

      loop do
        rd, wr, er = IO.select(@sockets, [], @sockets) # read, [write, [error, [timeout]]]

        # For each read socket accept a message
        rd.each{|s|
          client = s.accept                       # Accept connection
          client.puts("#{@msg_fields.length}")    # Say the message length
          info = accept_message(client)           # Accept data
          client.close                            # Close
          dispatch(info)                          # Process stuff
        }

        # Else, er, something, TODO.
        er.each{|s|
          puts "SOCKET ERROR: #{s}"
        }
      end
    end

    def close
      @sockets.each{|s| s.close}
    end

    private

    def dispatch(info)
      if not @thread then
        begin
          @op.call(info)
        rescue Exception => e
          $stderr.puts "Exception in daemon callback: #{e}"
          $stderr.puts e.backtrace.join("\n")
        end
      else
        Thread.new{
          begin
            @op.call(info)
          rescue Exception => e
            $stderr.puts "Exception in daemon callback: #{e}"
            $stderr.puts e.backtrace.join("\n")
          end
        }
      end
    end


    def accept_message(client)

      # Info to make the message from
      info = []
      Timeout::timeout(CLIENT_TIMEOUT){
        while( info.length < @msg_fields.length ) do
          info << client.readline.chomp
        end
      }

      # If there's not enough info, NACK
      if info.length != @msg_fields.length then
        client.write(NACK)
        return
      end

      # Base64 unencode everything but item 1
      info.map!{|x| Base64.strict_decode64(x.chomp) } 
      
      # Build an output hash
      hash = {}
      info.each_index{|i|
        hash[@msg_fields[i]] = info[i]
      }

      # Lastly, ack
      client.write(ACK)

      return hash
    end
  end

  class Client
    def initialize(hostname='localhost', port=4000)
      @hostname = hostname
      @port = port.to_i
    end

    def send(fields)
      # Construct the correct data format
      fields.map!{|x| Base64.strict_encode64(x.to_s)}
      msg = fields.join("\n") + "\n"

      # connect
      s = TCPSocket.new(@hostname, @port)
    
      # Check length
      msg_length = s.readline.to_i
      raise "Data size mismatch" if fields.length != msg_length

      # send
      s.write(msg)
      
      # check ack/nack
      code = s.read.chomp.strip
      s.close

      return (code == ACK)
    end
  end
end



if __FILE__ == $0 then

  DEFAULT_PORTS = (4000..4010).to_a

  ports = DEFAULT_PORTS
  d = MPPDaemon::Server.new(ports, [:time, :app, :name, :msg])

  puts "Waiting on #{ports}"
  d.listen
end
