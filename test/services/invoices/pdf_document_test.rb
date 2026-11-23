require "test_helper"

# The invoice PDF must be a structurally valid PDF (xref offsets included), not
# just a blob starting with "%PDF": Quick Look, Preview and mail clients all
# reject a bad xref.
class Invoices::PdfDocumentTest < ActiveSupport::TestCase
  setup do
    @request = analysis_requests(:guest_one)
    @invoice = @request.analysis_request_invoices.create!(
      amount_cents: 12_345,
      currency: "AUD",
      status: "sent",
      sent_at: Time.current,
      external_reference: "BT-7788"
    )
    @pdf = Invoices::PdfDocument.new(@invoice).render
  end

  test "renders a complete PDF document" do
    assert @pdf.start_with?("%PDF-1.4")
    assert @pdf.rstrip.end_with?("%%EOF")
    assert_includes @pdf, "startxref"
    assert_includes @pdf, "/Type /Catalog"
    assert_includes @pdf, "/BaseFont /Helvetica"
  end

  test "embeds the ball logo as an image XObject" do
    assert_includes @pdf, "/Subtype /Image"
    assert_includes @pdf, "/Width 512 /Height 512"
    assert_includes @pdf, "/Filter /DCTDecode"
    assert_includes @pdf, "/XObject << /Im1 7 0 R >>"
    assert_includes @pdf, "/Im1 Do"
  end

  test "renders without a logo when no asset is available" do
    pdf = Invoices::PdfDocument.new(@invoice, logo: nil).render

    refute_includes pdf, "/Subtype /Image"
    refute_includes pdf, "/Im1 Do"
    offsets = pdf.scan(/^(\d{10}) 00000 n $/).flatten
    assert_equal 6, offsets.size
  end

  test "prints the invoice, request and submitter details" do
    assert_includes @pdf, "INV-#{@invoice.id.to_s.rjust(4, '0')}"
    assert_includes @pdf, "ANL-2026-0002"
    assert_includes @pdf, "Match Review"
    assert_includes @pdf, "Jane Guest"
    assert_includes @pdf, "jane@example.com"
    assert_includes @pdf, "AUD 123.45"
    assert_includes @pdf, "BT-7788"
  end

  test "xref offsets point at their objects" do
    offsets = @pdf.scan(/^(\d{10}) 00000 n $/).flatten.map(&:to_i)
    assert_equal 7, offsets.size

    offsets.each_with_index do |offset, index|
      expected = "#{index + 1} 0 obj"
      assert_equal expected, @pdf.byteslice(offset, expected.bytesize)
    end

    startxref = @pdf[/startxref\n(\d+)/, 1].to_i
    assert_equal "xref", @pdf.byteslice(startxref, 4)
  end

  test "escapes parentheses and backslashes" do
    @request.update!(title: "Serve (toss) review \\ video")
    pdf = Invoices::PdfDocument.new(@invoice.reload).render

    assert_includes pdf, "Serve \\(toss\\) review \\\\ video"
  end
end
