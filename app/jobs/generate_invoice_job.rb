# frozen_string_literal: true

class GenerateInvoiceJob < ApplicationJob
  queue_as :default

  def perform(payment_id)
    payment = Payment.find(payment_id)
    return if payment.amount_cents.zero?
    return if Invoice.exists?(payment: payment)

    result = Invoicing::LibredteClient.new.emit_boleta(payment)

    if result[:success]
      invoice = Invoice.create!(
        payment: payment,
        user: payment.payer,
        folio: result[:folio],
        provider: 'libredte',
        provider_id: result[:provider_id],
        status: :issued,
        raw_response: result[:raw_response] || {}
      )
      attach_pdf(invoice, result[:pdf_binary])
      InvoiceMailer.invoice_issued(invoice).deliver_later
    else
      Invoice.create!(
        payment: payment,
        user: payment.payer,
        provider: 'libredte',
        status: :failed,
        raw_response: result[:raw_response] || {}
      )
    end
  end

  private

  def attach_pdf(invoice, pdf_binary)
    return if pdf_binary.blank?

    invoice.pdf.attach(
      io: StringIO.new(pdf_binary),
      filename: invoice.pdf_filename,
      content_type: 'application/pdf'
    )
  end
end
