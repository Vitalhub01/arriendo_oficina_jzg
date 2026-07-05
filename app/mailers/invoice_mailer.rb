# frozen_string_literal: true

class InvoiceMailer < ApplicationMailer
  def invoice_issued(invoice)
    @invoice = invoice
    @booking = invoice.payment.booking

    if invoice.pdf.attached?
      attachments[invoice.pdf_filename] = {
        mime_type: 'application/pdf',
        content: invoice.pdf.download
      }
    end

    mail(
      to: invoice.user.email,
      subject: "Boleta #{invoice.folio} — Oficina JZG"
    )
  end
end
