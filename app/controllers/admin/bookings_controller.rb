# frozen_string_literal: true

module Admin
  class BookingsController < Admin::BaseController
    def index
      scope = Booking.includes(:space, :profesional, :payment).order(start_at: :desc)
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where(box_id: params[:space_id]) if params[:space_id].present?
      @pagy, @bookings = pagy(scope)
    end

    def show
      @booking = Booking.find(params.expect(:id))
    end

    def update
      @booking = Booking.find(params.expect(:id))

      if params[:cancel].present?
        result = Bookings::Cancel.new(booking: @booking, actor: current_user).call
        flash_key = result.success? ? :notice : :alert
        flash[flash_key] = result.success? ? 'Reserva cancelada' : result.errors.join(', ')
      end

      redirect_to admin_booking_path(@booking)
    end
  end
end
