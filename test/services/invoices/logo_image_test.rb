require "test_helper"

# Logo embedding for the invoice PDF (IDENTITY-265).
#
# The shipped asset is a JPEG named ball.png, so the DCTDecode path matters most;
# the PNG path is pinned too because the asset can be swapped without code
# changes and PDFs cannot embed PNG bytes directly.
class Invoices::LogoImageTest < ActiveSupport::TestCase
  test "loads the shipped logo as a JPEG image XObject payload" do
    logo = Invoices::LogoImage.load

    assert logo, "expected public/ball.png to be readable"
    assert_equal 512, logo.width
    assert_equal 512, logo.height
    assert_equal "DCTDecode", logo.filter
    assert_equal "/DeviceRGB", logo.color_space
    assert logo.data.start_with?("\xFF\xD8".b)
  end

  test "returns nil for a missing or unsupported file" do
    assert_nil Invoices::LogoImage.load(Rails.root.join("public", "does-not-exist.png"))
    assert_nil Invoices::LogoImage.from_bytes("not an image")
  end

  test "decodes a truecolor PNG into raw RGB samples" do
    # 2×2: red, green / blue, white — filter byte 0 on each scanline.
    png = build_png(2, 2, [
      "\x00" + [ 255, 0, 0, 0, 255, 0 ].pack("C*"),
      "\x00" + [ 0, 0, 255, 255, 255, 255 ].pack("C*")
    ].join)

    logo = Invoices::LogoImage.from_bytes(png)

    assert logo, "expected the PNG to decode"
    assert_equal 2, logo.width
    assert_equal 2, logo.height
    assert_equal "FlateDecode", logo.filter
    assert_equal "/DeviceRGB", logo.color_space
    assert_equal [ 255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255 ].pack("C*"),
                 Zlib::Inflate.inflate(logo.data)
  end

  test "composites PNG alpha onto white" do
    png = build_png(1, 1, "\x00" + [ 0, 0, 0, 0 ].pack("C*"), color_type: 6)

    logo = Invoices::LogoImage.from_bytes(png)

    assert_equal [ 255, 255, 255 ].pack("C*"), Zlib::Inflate.inflate(logo.data)
  end

  private

  def build_png(width, height, rows, color_type: 2)
    ihdr = [ width, height, 8, color_type, 0, 0, 0 ].pack("NNCCCCC")

    Invoices::LogoImage::PNG_SIGNATURE +
      png_chunk("IHDR", ihdr) +
      png_chunk("IDAT", Zlib::Deflate.deflate(rows)) +
      png_chunk("IEND", "")
  end

  def png_chunk(type, data)
    [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N")
  end
end
