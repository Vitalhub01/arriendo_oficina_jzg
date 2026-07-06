# frozen_string_literal: true

require 'test_helper'

module Invoicing
  class LibredteClientTest < ActiveSupport::TestCase
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

    test 'stub mode returns folio and pdf binary' do
      result = LibredteClient.new.emit_boleta(@payment)

      assert result[:success]
      assert_equal "DEV-#{@payment.id}", result[:folio]
      assert result[:provider_id].start_with?('stub-')
      assert result[:pdf_binary].present?
      assert result[:pdf_binary].start_with?('%PDF')
      assert result[:raw_response][:stub]
    end
  end
end
