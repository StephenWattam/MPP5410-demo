
class Message
  def initialize(source, name, message, time = Time.now)
    @source   = source
    @name     = name
    @message  = message
    @time     = time
  end

  def marshal
    puts "STUB: marshal in Message"
  end

  def self.unmarshal(str)
    puts "STUB: unmarshal in Message"
  end
end
