module Invoices
  # Minimal, dependency-free PDF invoice (IDENTITY-265).
  #
  # The repository has no PDF gem (no Prawn/wkhtmltopdf/Grover), so this writes
  # a valid PDF 1.4 document by hand: one A4 page, the standard Helvetica
  # Type1 fonts that every PDF reader ships with, and a single content stream.
  # That is enough for an invoice, keeps the deploy free of native binaries, and
  # is deterministic — the mailer test can assert on the bytes.
  #
  # Structure (xref offsets are computed while assembling, never hard-coded):
  #   1 Catalog → 2 Pages → 3 Page → 4/5 Fonts, 6 Content stream.
  class PdfDocument
    PAGE_WIDTH = 595
    PAGE_HEIGHT = 842
    MARGIN = 56

    def initialize(invoice, logo: LogoImage.load, bank: AppSetting.bank_details)
      @invoice = invoice
      @request = invoice.analysis_request
      @logo = logo
      @bank = bank
    end

    def render
      objects = [
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        page_object,
        font_object("Helvetica"),
        font_object("Helvetica-Bold"),
        content_object
      ]
      objects << image_object if logo?

      assemble(objects)
    end

    def logo?
      @logo.present?
    end

    def filename
      "#{invoice_number}.pdf"
    end

    def invoice_number
      @invoice.number
    end

    private

    def page_object
      resources = "/Font << /F1 4 0 R /F2 5 0 R >>"
      resources += " /XObject << /Im1 #{image_object_number} 0 R >>" if logo?

      "<< /Type /Page /Parent 2 0 R " \
        "/MediaBox [0 0 #{PAGE_WIDTH} #{PAGE_HEIGHT}] " \
        "/Resources << #{resources} >> " \
        "/Contents 6 0 R >>"
    end

    def image_object_number
      7
    end

    def image_object
      header = "<< /Type /XObject /Subtype /Image " \
               "/Width #{@logo.width} /Height #{@logo.height} " \
               "/ColorSpace #{@logo.color_space} /BitsPerComponent 8 " \
               "/Filter /#{@logo.filter} /Length #{@logo.data.bytesize} >>\nstream\n"
      header.b << @logo.data.b << "\nendstream"
    end

    def font_object(name)
      "<< /Type /Font /Subtype /Type1 /BaseFont /#{name} " \
        "/Encoding /WinAnsiEncoding >>"
    end

    def content_object
      stream = content
      "<< /Length #{stream.bytesize} >>\nstream\n#{stream}\nendstream"
    end

    # --- page content -----------------------------------------------------

    def content
      lines = []
      y = PAGE_HEIGHT - MARGIN

      if logo?
        size = 34
        lines << "q #{size} 0 0 #{size} #{MARGIN} #{y - size + 8} cm /Im1 Do Q"
      end
      brand_x = logo? ? MARGIN + 44 : MARGIN

      lines << text(brand_x, y - 6, "BEACH VOLLEYBALL HUB", size: 13, bold: true)
      lines << text(brand_x, y - 22, "Video analysis services", size: 9)
      lines << text(PAGE_WIDTH - MARGIN - 150, y - 4, "INVOICE", size: 24, bold: true)
      lines << text(PAGE_WIDTH - MARGIN - 150, y - 24, invoice_number, size: 11, bold: true)

      y -= 56
      lines.concat(meta_block(y))

      y -= 108
      lines << rule(y + 12)
      lines << text(MARGIN, y - 4, "BILLED TO", size: 8, bold: true)
      lines << text(MARGIN, y - 20, submitter_name, size: 11)
      lines << text(MARGIN, y - 34, submitter_email, size: 10) if submitter_email.present?

      y -= 78
      lines << rule(y + 14)
      lines << text(MARGIN, y, "DESCRIPTION", size: 8, bold: true)
      lines << text(PAGE_WIDTH - MARGIN - 70, y, "AMOUNT", size: 8, bold: true)

      description_lines.each_with_index do |line, index|
        lines << text(MARGIN, y - 20 - (index * 14), line, size: 10)
      end

      y -= 20 + (description_lines.size * 14) + 16
      lines << rule(y + 10)
      lines << text(PAGE_WIDTH - MARGIN - 170, y - 6, "TOTAL (#{@invoice.currency})", size: 10, bold: true)
      lines << text(PAGE_WIDTH - MARGIN - 70, y - 6, amount_label, size: 12, bold: true)

      y -= 46
      lines.concat(notes(y))

      # Bank account details for payment
      lines.concat(bank_details(y))

      lines << text(MARGIN, 64, "Thank you for choosing Beach Volleyball Hub.", size: 9)
      lines << text(MARGIN, 50, "Questions about this invoice? Reply to the email it arrived with.", size: 8)

      lines.join("\n") << "\n"
    end

    def meta_block(y)
      rows = [
        [ "Issued", issued_on ],
        [ "Status", @invoice.status.to_s.upcase ],
        [ "Reference", @request.reference ]
      ]
      rows << [ "External ref.", @invoice.external_reference.to_s ] if @invoice.external_reference.present?
      rows << [ "Paid on", @invoice.paid_at.to_date.to_fs(:long) ] if @invoice.paid_at.present?

      rows.each_with_index.map do |(label, value), index|
        row_y = y - (index * 14)
        text(PAGE_WIDTH - MARGIN - 150, row_y, label.to_s.upcase, size: 7) +
          "\n" +
          text(PAGE_WIDTH - MARGIN - 80, row_y, value.to_s, size: 9, bold: true)
      end
    end

    def notes(y)
      notes = []
      if @invoice.external_reference.present?
        notes << "Payment reference: #{@invoice.external_reference}"
      end
      notes << "Please quote #{invoice_number} when paying so we can match your payment."
      notes << "Work begins once payment is received."

      notes.each_with_index.map do |line, index|
        text(MARGIN, y - (index * 13), fit(line, 9, PAGE_WIDTH - (MARGIN * 2)), size: 9)
      end
    end

    def bank_details(y)
      return [] unless @bank.present? && @bank[:name].present?

      lines = []
      lines << rule(y + 10)
      lines << text(MARGIN, y - 30, "BANK ACCOUNT DETAILS", size: 8, bold: true)

      bank_lines = []
      bank_lines << "Bank: #{@bank[:name]}"
      bank_lines << "Account: #{@bank[:account_name]}"
      bank_lines << "BSB: #{@bank[:bsb]}"
      bank_lines << "Account #: #{@bank[:account]}"

      bank_lines.each_with_index do |line, index|
        lines << text(MARGIN, y - 43 - (index * 13), fit(line, 9, PAGE_WIDTH - (MARGIN * 2)), size: 9)
      end

      lines
    end

    def description_lines
      lines = [ fit("#{@request.package_name} — #{@request.title}", 10, 360) ]
      lines << "Analysis request #{@request.reference}" if @request.reference.present?
      lines << "Requested #{@request.submitted_at.to_date.to_fs(:long)}" if @request.submitted_at.present?
      lines
    end

    def submitter_name
      @request.account&.full_name.presence || @request.guest_name.presence || "Analysis request submitter"
    end

    def submitter_email
      @request.account&.email.presence || @request.guest_email
    end

    def issued_on
      @invoice.created_at.to_date.to_fs(:long)
    end

    def amount_label
      "#{@invoice.currency} #{format('%.2f', @invoice.amount_cents / 100.0)}"
    end

    # --- primitives -------------------------------------------------------

    def text(x, y, value, size:, bold: false)
      font = bold ? "F2" : "F1"
      "BT /#{font} #{size} Tf #{x} #{y} Td (#{escape(value)}) Tj ET"
    end

    def rule(y, from: MARGIN, to: PAGE_WIDTH - MARGIN)
      "0.6 w 0.78 0.78 0.78 RG #{from} #{y} m #{to} #{y} l S"
    end

    # Approximate Helvetica width so long values never run off the page.
    def fit(value, size, max_width)
      text = value.to_s
      per_char = size * 0.52
      capacity = [(max_width / per_char).floor, 4].max
      return text if text.length <= capacity

      "#{text[0, capacity - 1]}…"
    end

    def escape(value)
      text = value.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?")
      text.gsub("\\", "\\\\\\\\").gsub("(", "\\(").gsub(")", "\\)")
    end

    # --- file assembly ----------------------------------------------------

    def assemble(objects)
      body = +"%PDF-1.4\n"
      body.force_encoding(Encoding::BINARY)
      offsets = []

      objects.each_with_index do |object, index|
        offsets << body.bytesize
        # The image object carries raw JPEG bytes, so build the entry as binary;
        # interpolating it into a UTF-8 string would raise on invalid sequences.
        body << "#{index + 1} 0 obj\n".b
        body << object.b
        body << "\nendobj\n"
      end

      xref_offset = body.bytesize
      body << "xref\n0 #{objects.size + 1}\n"
      body << "0000000000 65535 f \n"
      offsets.each { |offset| body << format("%010d 00000 n \n", offset) }
      body << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R >>\n"
      body << "startxref\n#{xref_offset}\n%%EOF\n"
      body
    end
  end
end
