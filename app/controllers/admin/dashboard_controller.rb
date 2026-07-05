# frozen_string_literal: true

module Admin
  class DashboardController < Admin::BaseController
    def index
      @spaces_count = Space.count
      @bookings_count = Booking.count
      @professionals_count = User.profesional.count
      @bookings_today = Booking.where(start_at: Time.current.all_day).count
      @month_revenue = Booking.confirmed
                              .where(start_at: Time.current.all_month)
                              .sum(:total_amount_cents)
      paid = Payment.approved.count
      total_payments = Payment.where(status: %i[approved rejected]).count
      @conversion_rate = total_payments.positive? ? ((paid.to_f / total_payments) * 100).round(1) : 0
      @recent_bookings = Booking.order(created_at: :desc).limit(10).includes(:space, :profesional)
    end
  end
end
