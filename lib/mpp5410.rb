
module MPP5410

  class MPP5410Device

    # Hardware selectable state
    @handshake      = :handware
    @baud           = 9600
    @ply            = :normal
    @labels         = false
    @serial         = true

    # Software selectable state
    # FIXME: estimate what charsets these actually are for the machine
    CHARSETS       = { :USA        => {:cmd => [27,82,0], :set => "ISO8859-1"},
                       :France    => {:cmd => [27,82,1], :set => "LATIN1"},
                       :Germany   => {:cmd => [27,82,2], :set => "LATIN1"},
                       :UK        => {:cmd => [27,82,3], :set => "LATIN1"},
                       :Denmark1  => {:cmd => [27,82,4], :set => "LATIN1"},
                       :Sweden    => {:cmd => [27,82,5], :set => "LATIN1"},
                       :Italy     => {:cmd => [27,82,6], :set => "LATIN1"},
                       :Spain     => {:cmd => [27,82,7], :set => "LATIN1"},
                       :Japan     => {:cmd => [27,82,8], :set => "LATIN1"},
                       :Norway    => {:cmd => [27,82,9], :set => "LATIN1"},
                       :Denmark2  => {:cmd => [27,82,10], :set => "LATIN1"}
                      }
    DEFAULT_CHARSET = :UK
    @charset        = :UK

    # Is underline on?
    @underline      = false
    UNDERLINE_ON    = [27, 45, 1]
    UNDERLINE_OFF   = [27, 45, 0]

    # Reset the printer
    RESET           = [27, 64]

    # Is bold on?
    @bold           = false
    BOLD_ON         = [27, 71]
    BOLD_OFF        = [27, 72]

    # Is inverse on?
    @inverse        = false
    INVERSE_ON      = [27, 123, 1]
    INVERSE_OFF     = [27, 123, 0]

    # Is reverse colours on?
    @reverse        = false
    REVERSE_ON      = [27, 105, 1]
    REVERSE_OFF     = [27, 105, 0]

    # How far to feed paper so we can see output
    LABEL_ADVANCE   = [27, 102]
    DEFAULT_FEED_PAST_HOUSING = 7

    # Is double width mode on?
    @double_width   = false
    DOUBLE_WIDTH_ON = [27, 87, 1]
    DOUBLE_WIDTH_OFF= [27, 87, 0]

    # Is double height mode on?
    @double_height    = false
    DOUBLE_HEIGHT_ON  = [27, 119, 1]
    DOUBLE_HEIGHT_OFF = [27, 119, 0]

    # cancel
    CANCEL          = [24]

    # page length tags
    @page_length    = nil
    PAGE_LENGTH_PREFIX  = [27, 67]  # [n]

    # Chars per line
    @char_per_line  = 24
    CHARS_PER_LINE  = [24, 32, 48]

    # horizontal tabs
    @horizontal_tabs  = nil
    HORIZONTAL_TAB_PREFIX = [27, 68] # [n]
   
    # Print density
    @print_density  = 1
    PRINT_DENSITIES = [1,2,3,4] # 1 is lightest, is default, 4 is darkest.  3 is label default.

    # Misc chars
    # TODO: some interface to these
    HORIZONTAL_TAB  = [9]
    LINE_FEED       = [10]
    FORM_FEED       = [12]
    CARRIAGE_RETURN = [13]

    # Set barcode height
    @barcode_height = nil
    BARCODE_HEIGHT_PREFIX = [29, 104] # [n > 1, <255]

    # Set barcode magnification
    @barcode_magnification = nil
    BARCODE_MAGNIFICATION_PREFIX = [29, 119] # [n]

    # Set barcode start position
    @barcode_start_position = [nil, nil]
    BARCODE_START_POSITION_PREFIX = [27, 36] # [x, y]

    # Barcode printing
    # TODO: quick checks on data length and/or checksums
    BARCODE_TYPES     = {:'UPC-A'   => 0,
                         :'UCP-E'   => 1,
                         :EAN13     => 2,
                         :EAN8      => 3,
                         :Code39    => 4,
                         :'2of5'    => 5,
                         :Codabar   => 6,
                         :CODE128   => 7
                        }
    BARCODE_TYPE_PREFIX = [29, 107]

    # Image types
    IMAGE_FORMATS       = { 8  => {:single => {:cmd => 0, :bytes_per_col => 1},
                                   :double => {:cmd => 1, :bytes_per_col => 2},
                                  },
                            24 => {:single => {:cmd => 32, :bytes_per_col => 3},
                                   :double => {:cmd => 33, :bytes_per_col => 6},
                                  }
                          }
    IMAGE_FORMAT_PREFIX = [27, 42]  # [n] [n1, n2] [d]
    IMAGE_DEFAULT_PREFIX = [27, 75] # n1 n2 [d]
    IMAGE_DEFAULT_PINS = 8  
    IMAGE_COLUMNS_PER_LINE  = 192 # 192 cols per line max


    # Control chars
    XON = 17.chr
    XOFF = 19.chr

    # Estimate delay for no flow control
    ESTIMATE_CHUNK_SIZE = 10    # in bytes
    ESTIMATE_CHUNK_DELAY = 0.1  # in seconds

    # Create a new land of wonder and joy, i.e. driver object
    def initialize(device_file, flow_control = :hardware)
      raise "file is not writable" if not File.writable?(device_file)
      raise "file is not character device" if not File.chardev?(device_file)
      @dev = File.open(device_file, 'wb+')
      @flow_control = flow_control
      set_charset(DEFAULT_CHARSET)
    end

    # Open a device with optional block
    def self.open(device_file, flow_control = :hardware)
      # Construct a new deely.
      me = new(device_file, flow_control)

      if block_given? then
        # Yield the connected self
        yield(me)
        # Ensure we close
        me.close
      end

      return me
    end




    # image processing
    def plot_bitfield(data, pins=nil, density=nil)
      # TODO: check data length per-format
      #       check data format fits on page
      #
       
      defaults_loaded = false
      if not pins or not density then
        defaults_loaded = true
        $stdout.puts "STUB: guessing density from current settings."
        pins = IMAGE_DEFAULT_PINS
      end

      # Compute arguments to the box.
      #
      # At 24 pins, we have three bits per "column"
      # At 8 pins, each bit defines a single column
      columns = (data.length / (pins/8)).to_i
      raise "data for image is not divisible by #{pins/8} bytes." if not columns == (data.length.to_f / (pins/8).to_f)

      # n1 and n2 encode pins in a weird way, spanning the byte:
      n1 = columns % 255 # mod
      n2 = columns / 255 # integer division
     
      # Default i1, else load from list
      # bytes_per_col = defaults_loaded ? 1 : IMAGE_FORMATS[pins][density][:bytes_per_col]
       
      if defaults_loaded then
        write_raw( IMAGE_DEFAULT_PREFIX + [n1, n2] + data )
      else
        raise "no such image pin count: #{pins}"                if not IMAGE_FORMATS.include?(pins)
        raise "number of pins must be in #{IMAGE_FORMATS.keys}" if not IMAGE_FORMATS.keys.include?(pins)
        raise "density must be in #{IMAGE_FORMATS[pins].keys}"  if not IMAGE_FORMATS[pins].keys.include?(density)

        write_raw( IMAGE_FORMAT_PREFIX + [IMAGE_FORMATS[pins][density][:cmd]] + [n1, n2] + data )
      end
    end

    # With 192 "columns" to a page, we have to adjust for various densities.
    # This is done with the IMAGE_FORMATS constant
    def bytes_per_image_line(pins, density)
      IMAGE_COLUMNS_PER_LINE * IMAGE_FORMATS[pins][density][:bytes_per_col]
    end

    # Returns the number of columns rendered for a given density in an image
    def columns_per_image_line(density)
      IMAGE_COLUMNS_PER_LINE * ((density == :double) ? 2 : 1)
    end

    # Plot an image from ImageMagick or disk
    def plot_image(image, pins, density, margin=0, resize=false)
      plot_bitfield( image_to_bitfield( image, pins, density, margin, resize), pins,  :single )
    end

    # Plot an RMagick image on a virtual surface.
    # FIXME: this is subtly broken in a few ways.
    def image_to_bitfield(image, pins, density, margin=0, resize=false)
      require 'RMagick'

      # Load from file if asked to do so.
      if image.is_a?(String) and File.exist?(image) then
        image = Magick::Image::read(image).first
      end

      # Check we can plot it in this mode
      max_width = columns_per_image_line(density)
      puts "MAX WIDTH(cols) : #{max_width}"
      image = image.resize_to_fit(max_width)          if resize
      raise "Image is too large to plot" if not resize and image.columns > max_width

      # Pixels are NOT square, being instead a ratio of the density and number of
      # pins per row.  This is vaguely analogous to the number of bits per pixel,
      # in that it is proportional to the very same...
      adjusted_height = image.rows
      adjusted_height /= (IMAGE_FORMATS[pins][density][:bytes_per_col])
      # adjusted_height /= 0.8
      image.resize!(image.columns, adjusted_height);


      # Compute the number of lines, essentially bg.rows.ceil(pins)
      # This ensures we round up to the number of "lines" we can print
      rows = image.rows / pins.to_f
      rows = (rows.to_i + 1) if not rows == rows.to_i
      rows *= pins

      # TODO: copy it into something exactly max_width * image.height size, all white
      bg = Magick::Image.new(max_width, rows){   # round up to pins height
        self.background_color = "white"; 
      }
      bg.composite!(image, margin, 0, Magick::SrcAtopCompositeOp)
      bg = bg.quantize(2, Magick::GRAYColorspace)


      # At this point the image is quantised and ready for conversion
      # image.display
      # bg.display
    
      bitfield = []
      lines = bg.rows / pins
      puts "IMAGE MODE: #{pins} #{density}"
      puts "LINES: #{lines} @ #{pins} pins = #{bg.rows} rows."
      puts "Density: #{density} * #{IMAGE_COLUMNS_PER_LINE}/line = #{bg.columns} cols."
      pixels = 0
      0.upto(lines-1){|row|    # along each row
        0.upto(bg.columns-1){|pix_x| 

          # Build a byte for this line (line may require > 1 byte)
          bytes = [0] * (pins / 8)

          (pins-1).downto(0){|y_offset| # for each byte, 
            pix_y = (row * pins) + y_offset

            # Work out which bit of which byte
            byte_offset = y_offset % 8
            byte        = y_offset / 8

            # output handy stuff
            # $stdout.puts "[#{byte}](#{pix_x}, #{pix_y}) : #{bg.pixel_color(pix_x, pix_y).red}"

            # Set the (y_offset/8)'th byte to have this particular pixel on/off.
            bytes[byte] |= (1 << (7-byte_offset)) if bg.pixel_color(pix_x, pix_y).red < 50
            pixels += 1
          }
          # $stdout.puts "bytes: #{bytes}"

          # Add the byte
          bitfield += bytes
        }
      }

      puts "BITFIELD LENGTH: #{bitfield.length} vs #{bytes_per_image_line(pins, density) * lines}"
      puts "PIXEL COUNT: #{pixels} (#{bg.columns} * #{lines*pins}) (#{bitfield.length / lines} bytes/line)"

      return bitfield
    end

    def flow_control
      @flow_control || :none
    end

    # Read barcode start position
    def barcode_start_position
      @barcode_start_position
    end

    # Set barcode start position
    def barcode_start_position=(xy)
      raise "Barcode start position should be an [x,y] array" if not xy.is_a?(Array) and xy.length == 0
      @barcode_start_position = xy
      write_raw( BARCODE_START_POSITION_PREFIX + xy )
    end

    # Print a barcode
    def print_barcode(type, values)
      raise "no such barcode type: #{type}" if not BARCODE_TYPES[type]
      # TODO: check values.length per barcode type.
      
      # Convert values into ints if not done
      values.map!{|x|
        x = x.ord if x.is_a?(String)
        x = x.to_i
      }

      if type != :CODE128 then
        write_raw( (BARCODE_TYPE_PREFIX + [BARCODE_TYPES[type]]) + values + [0])
      else
        # TODO: also handle 'n' from the datasheet
        write_raw( (BARCODE_TYPE_PREFIX + [BARCODE_TYPES[type]]) + values)
      end

    end

    # Query barcode magnification
    def barcode_magnification
      @barcode_magnification
    end

    # set barcode magnification
    def barcode_magnification=(b)
      raise "Magnification must be between 2 and 4 inclusive." if b > 4 or b < 2
      @barcode_magnification = b.to_i
      write_raw( BARCODE_MAGNIFICATION_PREFIX + [@barcode_magnification] )
    end

    # read barcode height
    def barcode_height
      @barcode_height
    end

    # Set barcode height
    def barcode_height=(b)
      raise "Barcode height must be between 1 and 255" if b > 255 or b < 1
      @barcode_height = b.to_i
      write_raw( BARCODE_HEIGHT_PREFIX + [@barcode_height] )
    end

    # Set chars per line if it's valid
    def char_per_line=(cpl)
      raise "Invalid value for chars-per-line: #{cpl}" if not CHARS_PER_LINE.include?(cpl.to_i)
      @char_per_line = cpl.to_i
      set_print_mode
    end

    # Set print density
    def print_density=(pd)
      raise "Invalid value for print density: #{pd}" if not PRINT_DENSITIES.include?(pd.to_i)
      @print_density = pd.to_i
      set_print_mode
    end

    # Options are stateful and read from other things
    def set_print_mode
      # Start off with a null mask
      mask = 0b00000000

      # Then combine it with the state from the object
      mask |= 0b00010000 if @double_height
      mask |= 0b00100000 if @double_width
      mask |= 0b10000000 if @double_width

      # and the numeric ones, done slightly stupidly here
      mask |= PRINT_DENSITIES.index(@print_density) << 2  # shift left two
      mask |= CHARS_PER_LINE.index(@char_per_line)        # don't shift this one

      # Write as a number
      write_raw([mask])
    end

    # Query horizontal_tabs
    def horizontal_tabs
      @horizontal_tabs
    end
     
    # Set horizontal_tabs
    def horizontal_tabs=(h)
      raise "Horizontal tabs cannot be below 0"     if h < 0
      raise "Horizontal tabs cannot be above 255"   if h > 255
      @horizontal_tabs = h.to_i
      write_raw( HORIZONTAL_TAB_PREFIX + [@horizontal_tabs] )
    end

    # Set the page length
    def page_length
      @page_length
    end

    # Set page length
    def page_length=(p)
      raise "Page length cannot be set to below 0"  if p < 0
      raise "Page length cannot be above 255"       if p > 255
      @page_length = p.to_i
      write_raw( PAGE_LENGTH_PREFIX + [@page_length] )
    end

    # Write text using current settings
    def print(msg)
      write_as_text(msg)
    end

    # equivalent of puts
    def puts(msg)
      print("#{msg}\n")
    end

    # Feed past housing
    def print_and_feed_paper 
      write_raw([27, 100, DEFAULT_FEED_PAST_HOUSING])
    end

    # Advance, as in LABEL_ADVANCE
    def label_advance
      write_raw(LABEL_ADVANCE)
    end

    # Cancel operations
    def cancel
      write_raw(CANCEL)
    end

    # Set country.  Basically this just sets the charset.
    def country=(c)
      raise "The device does not support the country #{c}" if not CHARSETS.keys.include?(c)
      set_charset(c)
    end

    # Query double height mode
    def double_height?
      @double_height
    end

    # Set double height mode
    def double_height=(h)
      @double_height = h
      write_raw( @double_height ? DOUBLE_HEIGHT_ON : DOUBLE_HEIGHT_OFF )
    end

    # Query double width mode
    def double_width?
      @double_width
    end

    # Set double width mode
    def double_width=(d)
      @double_width = d
      write_raw( @double_width ? DOUBLE_WIDTH_ON : DOUBLE_WIDTH_OFF )
    end

    # Query reverse
    def reverse?
      @reverse
    end

    # Set reverse
    def reverse=(r)
      @reverse = r
      write_raw( @reverse ? REVERSE_ON : REVERSE_OFF )
    end

    # Query inverse
    def inverse?
      @inverse
    end

    # Set inverse mode (upside-down)
    def inverse=(i)
      @inverse = i
      write_raw( @inverse ? INVERSE_ON : INVERSE_OFF )
    end

    # Query underline
    def underline?
      @underline
    end

    # Set underline mode
    def underline=(ul)
      @underline=ul
      write_raw( @underline ? UNDERLINE_ON : UNDERLINE_OFF )
    end

    # Is bold on?
    def bold?
      @bold
    end

    # Set bold
    def bold=(b)
      @bold = b
      write_raw( @bold ? BOLD_ON : BOLD_OFF )
    end

    # Reset the printer
    def reset
      write_raw( RESET )
    end

    # Set the character set (must be listed in CHARSETS)
    def set_charset(cs = DEFAULT_CHARSET)
      raise "not a valid charset: #{cs}" if not CHARSETS.keys.include?(cs)
      @charset = cs
      write_raw(CHARSETS[cs][:cmd])
    end

    # flush
    def flush
      @dev.flush
    end

    # Close the device
    def close
      flush
      @dev.close
    end

  private
    # Write text in whatever the current character set is.
    def write_as_text(msg)
      if msg.ascii_only? then
        write_raw(msg)
      else
        write_raw(msg.encode(CHARSETS[@charset || DEFAULT_CHARSET][:set], 
                              :replace => '?', :undef => true, :invalid => true, :universal_newline => true))
      end
    end

    # Write things raw (ascii encoding NOT enforced)
    def write_raw(msg = nil)
      msg = msg.map{|x| x.chr}.join if msg.is_a?(Array)

      $stderr.puts "Flow control: #{flow_control}"

      if @flow_control == :hardware then
        @dev.syswrite(msg)
      elsif @flow_control == :software then
        require 'timeout'
        msg.each_char{|c|
          # Write a char
          # $stdout.print(c)
          @dev.syswrite(c)
          # @dev.flush # optional?

          control = ""
          begin
          Timeout::timeout(0.001){
            # Check flow control
            control = @dev.read(1)
            $stderr.puts "===> READ #{control.ord}"
          }
          rescue
          end


          if control == XOFF then #xoff
            while(not (@dev.read(1) == XON))do
              sleep(0.1)
            end
          end
        }
      elsif @flow_control == :estimate then  # no flow control, but delay
        chunks = msg.length / ESTIMATE_CHUNK_SIZE
        chunks.times{|chunk|
          $stdout.puts "-> #{(chunk * ESTIMATE_CHUNK_SIZE)} - #{((chunk+1)*ESTIMATE_CHUNK_SIZE)}"
          @dev.syswrite(msg[(chunk * ESTIMATE_CHUNK_SIZE)..((chunk+1)*ESTIMATE_CHUNK_SIZE)])
          sleep(ESTIMATE_CHUNK_DELAY)
        }
      else # no flow control at all
        @dev.syswrite(msg)
      end
    end
  end
end



# Test pack
if __FILE__ == $0 then
  puts "Opening..."

  # Open a handle to the mpp deely
  mpp = MPP5410::MPP5410Device.open("/dev/ttyUSB0", :hardware)

  mpp.puts "Using flow control: #{mpp.flow_control}"
   mpp.puts("Text")

  # Test underline
  mpp.underline = true
  mpp.puts("Underline mode: #{mpp.underline?}")
  mpp.underline = false 
  mpp.puts("Underline mode: #{mpp.underline?}")

  # Test bold 
  mpp.bold = true
  mpp.puts("Bold mode: #{mpp.bold?}")
  mpp.bold = false 
  mpp.puts("Bold mode: #{mpp.bold?}")

  # Test inverse
  mpp.inverse = true
  mpp.puts("inverse mode: #{mpp.inverse?}")
  mpp.inverse = false 
  mpp.puts("inverse mode: #{mpp.inverse?}")

  # Test reverse
  mpp.reverse = true
  mpp.puts("Reverse mode: #{mpp.reverse?}")
  mpp.reverse = false 
  mpp.puts("Reverse mode: #{mpp.reverse?}")

  # Test double width
  mpp.double_width = true
  mpp.puts("Double Width mode: #{mpp.double_width?}")
  mpp.double_width = false 
  mpp.puts("Double Width mode: #{mpp.double_width?}")

  # Test double height mode
  mpp.double_height = true
  mpp.puts("Double height mode: #{mpp.double_height?}")
  mpp.double_height = false 
  mpp.puts("Double height mode: #{mpp.double_height?}")


  # Print a barcode
  mpp.puts "Test barcode"
  mpp.print_barcode(:EAN13, [9,7,8,1,5,9,9,8,6,9,5,2,0])
  mpp.barcode_height = 20
  mpp.puts "Shorter barcode (#{mpp.barcode_height})"
  mpp.print_barcode(:EAN13, [9,7,8,1,5,9,9,8,6,9,5,2,0])
  mpp.barcode_height = 200
  mpp.puts "Longer barcode (#{mpp.barcode_height})"
  mpp.print_barcode(:EAN13, [9,7,8,1,5,9,9,8,6,9,5,2,0])



  # Plot an image
  mpp.puts "Image @ 8SD:"
  imagedata = ["\xAA"]*mpp.bytes_per_image_line(8, :single)
  mpp.plot_bitfield(imagedata, 8, :single)
  mpp.puts "Image @ 8DD:"
  imagedata = ["\xAA"]*mpp.bytes_per_image_line(8, :double)
  mpp.plot_bitfield(imagedata, 8, :double)
  mpp.puts "Image @ 24SD:"
  imagedata = ["\xAA"]*mpp.bytes_per_image_line(24, :single)
  mpp.plot_bitfield(imagedata, 24, :single)
  mpp.puts "Image @ 24DD:"
  imagedata = ["\xAA"]*mpp.bytes_per_image_line(24, :double)
  mpp.plot_bitfield(imagedata, 24, :double)


  # Plot an image from a file
  # mpp.puts "DONE"
  # mpp.puts "DONE"
  # mpp.puts "DONE"
  # mpp.puts "DONE"
  # mpp.puts "DONE"
  # mpp.puts "DONE"
  mpp.plot_image("lena.jpg", 8, :single, 0, true)
  mpp.puts "DONE"
  # # 
  # mpp.puts "PLOTTING AT 8/SD"
  # mpp.puts "PLOTTING AT 8/SD"
  # mpp.puts "PLOTTING AT 8/SD"
  # mpp.plot_image("icon.png", 8, :single, 0, true)
  # mpp.puts "PLOTTING AT 8/DD"
  # mpp.puts "PLOTTING AT 8/DD"
  # mpp.puts "PLOTTING AT 8/DD"
  # mpp.plot_image("icon.png", 8, :double, 0, true)
  # mpp.puts "PLOTTING AT 24/SD"
  # mpp.puts "PLOTTING AT 24/SD"
  # mpp.puts "PLOTTING AT 24/SD"
  # mpp.plot_image("icon.png", 24, :single, 0, true)
  # mpp.puts "PLOTTING AT 24/DD"
  # mpp.puts "PLOTTING AT 24/DD"
  # mpp.puts "PLOTTING AT 24/DD"
  # mpp.plot_image("icon.png", 24, :double, 0, true)
  # mpp.puts "-------------"
  # mpp.puts "-------------"
  # mpp.puts "-------------"
  # mpp.puts "-------------"
  # mpp.puts "-------------"

  # Feed past the housing
  mpp.print_and_feed_paper

  # Close
  puts "Closing..."
  mpp.reset
  mpp.close


end
