# Tracks when the invoice PDF was emailed to the submitter (IDENTITY-265).
#
# `sent_at` already records that an invoice was issued; `emailed_at` records
# that the dedicated invoice email actually went out, which is a different
# action (staff can issue an invoice and email it separately, or resend it).
class AddEmailedAtToAnalysisRequestInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :analysis_request_invoices, :emailed_at, :datetime
  end
end
