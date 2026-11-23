module Invoices
  # Embeds the site logo in the invoice PDF (IDENTITY-265).
  #
  # PDFs do not accept PNG bytes: an image must be either JPEG (embedded
  # verbatim with /DCTDecode) or raw samples (usually /FlateDecode).
  # `public/ball.png` is, despite its name, a progressive JPEG — so the fast path
  # is a straight embed. PNG is supported too, in case the asset is replaced with
  # a real PNG: it is inflated, unfiltered and composited onto white (invoices
  # are printed, so transparency must not turn black).
  #
  # Anything unsupported returns nil; the invoice still renders without a logo
  # rather than failing the email.
  class LogoImage
    PATH = Rails.root.join("public", "ball.png")
    PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze
    PNG_CHANNELS = { 0 => 1, 2 => 3, 3 => 1, 4 => 2, 6 => 4 }.freeze

    attr_reader :width, :height, :color_space, :filter, :data

    def self.load(path = PATH)
      return nil unless path && File.file?(path)

      from_bytes(File.binread(path), source: path)
    rescue StandardError => e
      Rails.logger.warn("[invoice] logo unavailable (#{path}): #{e.class}: #{e.message}")
      nil
    end

    def self.from_bytes(bytes, source: "bytes")
      return new_jpeg(bytes) if jpeg?(bytes)
      return new_png(bytes) if png?(bytes)

      Rails.logger.warn("[invoice] unsupported logo format (#{source})")
      nil
    rescue StandardError => e
      Rails.logger.warn("[invoice] unreadable logo (#{source}): #{e.class}: #{e.message}")
      nil
    end

    def self.jpeg?(bytes)
      bytes.byteslice(0, 2) == "\xFF\xD8".b
    end

    def self.png?(bytes)
      bytes.byteslice(0, 8) == PNG_SIGNATURE
    end

    # JPEG dimensions live in the SOF marker; SOF2 (progressive) is what the
    # current asset uses, so every SOF variant except DHT/DAC/JPG counts.
    def self.new_jpeg(bytes)
      width, height, components = jpeg_frame(bytes)
      color_space = case components
                    when 1 then "/DeviceGray"
                    when 4 then "/DeviceCMYK"
                    else "/DeviceRGB"
                    end

      allocate.tap do |image|
        image.instance_variable_set(:@width, width)
        image.instance_variable_set(:@height, height)
        image.instance_variable_set(:@color_space, color_space)
        image.instance_variable_set(:@filter, "DCTDecode")
        image.instance_variable_set(:@data, bytes)
      end
    end

    def self.jpeg_frame(bytes)
      offset = 2
      while offset + 3 < bytes.bytesize
        marker = bytes.getbyte(offset + 1)
        offset += 2
        next if marker == 0xD8 || marker == 0xD9 || marker == 0x01

        length = bytes.byteslice(offset, 2).unpack1("n")
        if (0xC0..0xCF).cover?(marker) && ![ 0xC4, 0xC8, 0xCC ].include?(marker)
          height, width = bytes.byteslice(offset + 3, 4).unpack("nn")
          components = bytes.getbyte(offset + 7)
          return [ width, height, components ]
        end
        offset += length
      end

      raise "no JPEG frame header"
    end

    # 8-bit non-interlaced PNGs only (truecolor, truecolor+alpha, grayscale,
    # grayscale+alpha and palette).
    def self.new_png(bytes)
      width, height, color_type, bit_depth, interlace = png_header(bytes)
      unless bit_depth == 8 && interlace.zero?
        raise "unsupported PNG (depth #{bit_depth}, interlace #{interlace})"
      end

      palette, transparency = png_palette(bytes)
      raw = Zlib::Inflate.inflate(png_idat(bytes))
      rgb = png_to_rgb(raw, width, height, color_type, palette, transparency)

      allocate.tap do |image|
        image.instance_variable_set(:@width, width)
        image.instance_variable_set(:@height, height)
        image.instance_variable_set(:@color_space, "/DeviceRGB")
        image.instance_variable_set(:@filter, "FlateDecode")
        image.instance_variable_set(:@data, Zlib::Deflate.deflate(rgb))
      end
    end

    def self.png_header(bytes)
      raise "bad PNG signature" unless png?(bytes)

      width, height, bit_depth, color_type, _compression, _filter, interlace =
        bytes.byteslice(16, 13).unpack("NNCCCCC")
      [ width, height, color_type, bit_depth, interlace ]
    end

    def self.png_chunks(bytes)
      chunks = {}
      offset = 8
      while offset < bytes.bytesize
        length = bytes.byteslice(offset, 4).unpack1("N")
        type = bytes.byteslice(offset + 4, 4)
        payload = bytes.byteslice(offset + 8, length)
        (chunks[type] ||= []) << payload
        offset += 12 + length
      end
      chunks
    end

    def self.png_idat(bytes)
      png_chunks(bytes).fetch("IDAT").join
    end

    def self.png_palette(bytes)
      chunks = png_chunks(bytes)
      [ chunks["PLTE"]&.first, chunks["tRNS"]&.first ]

    def self.png_to_rgb(raw, width, height, color_type, palette, transparency)
      channels = PNG_CHANNELS.fetch(color_type)
      stride = width * channels
      previous = Array.new(stride, 0)
      output = +"".b
      offset = 0

      height.times do
        filter = raw.getbyte(offset)
        row = raw.byteslice(offset + 1, stride).bytes.to_a
        offset += 1 + stride
        unfilter!(row, previous, filter, channels)

        case color_type
        when 2
          output << row.pack("C*")
        when 6
          row.each_slice(4) do |r, g, b, a|
            output << [ r, g, b ].map { |c| blend(c, a) }.pack("C*")
          end
        when 0
          row.each { |gray| output << [ gray, gray, gray ].pack("C*") }
        when 4
          row.each_slice(2) do |gray, a|
            channel = blend(gray, a)
            output << [ channel, channel, channel ].pack("C*")
          end
        when 3
          row.each do |index|
            base = index * 3
            r, g, b = palette.byteslice(base, 3).bytes
            alpha = transparency&.getbyte(index) || 255
            output << [ r, g, b ].map { |c| blend(c, alpha) }.pack("C*")
          end
        end

        previous = row
      end

      output
    end

    def self.unfilter!(row, previous, filter, channels)
      row.each_index do |i|
        left = i >= channels ? row[i - channels] : 0
        up = previous[i]
        up_left = i >= channels ? previous[i - channels] : 0

        row[i] = case filter
                 when 0 then row[i]
                 when 1 then (row[i] + left) & 0xFF
                 when 2 then (row[i] + up) & 0xFF
                 when 3 then (row[i] + ((left + up) / 2)) & 0xFF
                 when 4 then (row[i] + paeth(left, up, up_left)) & 0xFF
                 else raise "unsupported PNG filter #{filter}"
                 end
      end
    end

    def self.paeth(left, up, up_left)
      estimate = left + up - up_left
      distance_left = (estimate - left).abs
      distance_up = (estimate - up).abs
      distance_up_left = (estimate - up_left).abs

      if distance_left <= distance_up && distance_left <= distance_up_left
        left
      elsif distance_up <= distance_up_left
        up
      else
        up_left
      end
    end

    def self.blend(channel, alpha)
      return channel if alpha == 255

      ((channel * alpha) + (255 * (255 - alpha))) / 255
    end

    private_class_method :new_jpeg, :new_png, :jpeg_frame, :png_header, :png_chunks,
                         :png_idat, :png_palette, :png_to_rgb, :unfilter!, :paeth, :blend
  end
end

    end
