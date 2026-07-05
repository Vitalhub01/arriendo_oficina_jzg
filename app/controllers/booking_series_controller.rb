# frozen_string_literal: true

class BookingSeriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_series, only: %i[show update]

  def index
    @pagy, @booking_series = pagy(policy_scope(BookingSeries).includes(:box).order(:starts_on))
  end

  def show
    authorize @series
    @bookings = @series.bookings.order(:start_at)
  end

  def update
    authorize @series
    action = params.dig(:booking_series, :status)

    case action
    when 'paused'
      @series.paused!
      cancel_future_pending_bookings
      notice = 'Serie pausada'
    when 'active'
      @series.active!
      GenerateSeriesBookingsJob.perform_later(@series.id)
      notice = 'Serie reanudada'
    when 'cancelled'
      @series.cancelled!
      cancel_future_pending_bookings
      notice = 'Serie cancelada'
    else
      return redirect_to @series, alert: 'Acción no válida'
    end

    redirect_to booking_series_path(@series), notice: notice
  end

  private

  def set_series
    @series = BookingSeries.find(params.expect(:id))
  end

  def cancel_future_pending_bookings
    @series.bookings.pending_payment.where(start_at: Time.current..).find_each do |booking|
      booking.update!(status: :cancelled)
    end
  end
end
