# frozen_string_literal: true

module Bookings
  class PaymentExpiryReminderJob < ApplicationJob
    queue_as :mailers

    def perform(booking_id = nil)
      if booking_id
        remind_booking(booking_id)
      else
        remind_in_payment_window
      end
    end

    private

    def remind_booking(booking_id)
      booking = Booking.find_by(id: booking_id)
      return unless booking&.pending_payment?
      return if booking.payment_expired?

      BookingMailer.payment_expiring_soon(booking).deliver_later
    end

    # Respaldo por si alguna reserva quedó sin jobs programados (datos antiguos, fallo al encolar).
    def remind_in_payment_window
      window_start = 15.minutes.from_now
      window_end = 30.minutes.from_now

      Booking.pending_payment
             .where(payment_expires_at: window_start..window_end)
             .find_each { |booking| remind_booking(booking.id) }
    end
  end
end
