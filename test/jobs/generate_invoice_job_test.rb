# frozen_string_literal: true

require 'test_helper'

class GenerateInvoiceJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    @box = boxes(:published_box)
    @renter = users(:renter)
    @slot_time = next_monday_at(hour: 10)
    @booking = Booking.create!(
      space: @box,
      profesional: @renter,
      start_at: @slot_time,
      end_at: @slot_time + 2.hours,
      hours: 2,
      duration_minutes: 120,
      total_amount_cents: @box.default_price_per_slot_cents * 2,
      status: :confirmed,
      booking_type: :slot_based
    )
    @payment = Payment.create!(
      booking: @booking,
      payer: @renter,
      amount_cents: @booking.total_amount_cents,
      status: :approved,
      payment_kind: :booking
    )
  end

  test 'creates invoice with pdf and enqueues mailer' do
    assert_enqueued_emails 1 do
      assert_difference 'Invoice.count', 1 do
        GenerateInvoiceJob.perform_now(@payment.id)
      end
    end

    invoice = Invoice.last
    assert invoice.issued?
    assert_equal 'libredte', invoice.provider
    assert invoice.pdf.attached?
    assert_equal invoice.pdf_filename, invoice.pdf.filename.to_s
  end

  test 'skips zero amount payments' do
    @payment.update_column(:amount_cents, 0)

    assert_no_difference 'Invoice.count' do
      GenerateInvoiceJob.perform_now(@payment.id)
    end
  end

  test 'skips when invoice already exists' do
    GenerateInvoiceJob.perform_now(@payment.id)

    assert_no_difference 'Invoice.count' do
      GenerateInvoiceJob.perform_now(@payment.id)
    end
  end
end
