# frozen_string_literal: true

module Bookings
  # Encola expiración y recordatorio de pago en el momento correcto (Sidekiq scheduled set),
  # en lugar de barrer la BD cada 5–15 minutos vía sidekiq-cron.
  class SchedulePaymentDeadlineJobs
    REMINDER_BEFORE_EXPIRY = 20.minutes

    def self.call(booking)
      new(booking).call
    end

    def initialize(booking)
      @booking = booking
    end

    def call
      return unless schedulable?

      expires_at = @booking.payment_expires_at
      ExpirePendingJob.set(wait_until: expires_at).perform_later(@booking.id)

      reminder_at = expires_at - REMINDER_BEFORE_EXPIRY
      return if reminder_at <= Time.current

      PaymentExpiryReminderJob.set(wait_until: reminder_at).perform_later(@booking.id)
    end

    private

    def schedulable?
      @booking.pending_payment? &&
        @booking.payment_expires_at.present? &&
        @booking.total_amount_cents.positive?
    end
  end
end
