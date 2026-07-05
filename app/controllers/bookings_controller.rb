# frozen_string_literal: true

class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_can_book!, only: %i[new create reschedule]
  before_action :set_booking, only: %i[show checkout cancel reschedule]

  def index
    @pagy, @bookings = pagy(
      policy_scope(Booking).includes(:space, :payment).order(start_at: :desc)
    )
  end

  def show
    authorize @booking
    if @booking.confirmed? && params[:collection_status] == 'approved'
      flash.now[:ga_event] = { name: 'payment_completed', params: { booking_id: @booking.id } }
      track_ga_flash_event
    end
  end

  def new
    @space = Space.published_spaces.find(params.expect(:space_id))
    authorize @space, :show?
  end

  def create
    @space = Space.published_spaces.find(params.expect(:space_id))
    authorize @space, :show?

    result = Bookings::Create.new(
      space: @space,
      profesional: current_user,
      params: booking_params
    ).call

    if result.success?
      flash[:ga_event] = { name: 'booking_started', params: { space_id: @space.id, booking_type: booking_params[:booking_type] } }
      if result.booking.confirmed?
        redirect_to result.booking, notice: 'Reserva confirmada con tu crédito'
      else
        redirect_to checkout_booking_path(result.booking)
      end
    else
      load_space_show_vars
      @errors = result.errors
      render 'spaces/show', status: :unprocessable_content
    end
  end

  def checkout
    authorize @booking

    if @booking.confirmed?
      redirect_to @booking, notice: 'Esta reserva ya está confirmada'
      return
    end

    result = nil
    @booking.with_lock do
      @booking.reload
      result = Payments::MercadoPago::CreatePreference.new(booking: @booking, payer: current_user).call
    end

    if result.success? && result.init_point.present?
      redirect_to result.init_point, allow_other_host: true
    else
      redirect_to @booking, alert: result.error || 'No se pudo iniciar el pago. Configura MERCADOPAGO_ACCESS_TOKEN.'
    end
  end

  def cancel
    authorize @booking, :cancel?
    result = Bookings::Cancel.new(booking: @booking, actor: current_user).call

    if result.success?
      redirect_to bookings_path, notice: 'Reserva cancelada'
    else
      redirect_to @booking, alert: result.errors.join(', ')
    end
  end

  def reschedule
    authorize @booking, :reschedule?

    result = Bookings::Reschedule.new(
      booking: @booking,
      actor: current_user,
      params: reschedule_params
    ).call

    if result.success?
      redirect_to result.booking, notice: 'Reserva reprogramada'
    else
      redirect_to @booking, alert: result.errors.join(', ')
    end
  end

  private

  def require_can_book!
    return if current_user.can_book?

    redirect_to onboarding_path, alert: 'Completa tu perfil profesional para reservar'
  end

  def set_booking
    @booking = Booking.find(params.expect(:id))
  end

  def load_space_show_vars
    @week_start = Date.current.beginning_of_week(:monday)
    @schedule = AvailabilityScheduleBuilder.new(@space, week_start: @week_start).build
  end

  def booking_params
    params.permit(:date, :start_time, :hours, :booking_type, :jornada_definition_id)
  end

  def reschedule_params
    params.permit(:date, :start_time, :hours, :jornada_definition_id)
  end
end
