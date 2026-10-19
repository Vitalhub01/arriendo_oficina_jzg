# frozen_string_literal: true

class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_can_book!, only: %i[new create reschedule]
  before_action :set_booking, only: %i[show checkout cancel reschedule apply_discount_code]

  def index
    @pagy, @bookings = pagy(
      policy_scope(Booking).includes(:space, :payment).order(start_at: :desc)
    )
  end

  def show
    authorize @booking
    Payments::MercadoPago::ProcessReturn.new(booking: @booking, params: params).call
    @booking.reload

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
      params: booking_params,
      require_terms_acceptance: true
    ).call

    if result.success?
      flash[:ga_event] = { name: 'booking_started', params: { space_id: @space.id, slot_count: booking_params[:slot_count] } }
      if result.booking.confirmed?
        redirect_to result.booking, notice: booking_created_notice('Reserva confirmada con tu crédito')
      else
        redirect_to result.booking, notice: booking_created_notice, status: :see_other
      end
    else
      load_space_show_vars
      @errors = result.errors
      render 'spaces/show', status: :unprocessable_content
    end
  end

  def apply_discount_code
    authorize @booking, :apply_discount_code?

    result = Bookings::ApplyDiscountCode.new(
      booking: @booking,
      code: params[:code],
      actor: current_user
    ).call

    if result.success?
      notice = if result.booking.confirmed?
                 'Código aplicado. Tu reserva quedó confirmada sin pago.'
               else
                 'Código de descuento aplicado'
               end
      redirect_to result.booking, notice: notice
    else
      redirect_to @booking, alert: result.errors.join(', ')
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

    if current_user.banned?
      redirect_to root_path, alert: 'Tu cuenta está suspendida. Contacta al administrador.'
    elsif current_user.professional_profile&.rejected?
      redirect_to root_path, alert: 'Tu perfil profesional no está habilitado para reservar. Contacta al administrador.'
    else
      redirect_to new_user_registration_path, alert: 'Regístrate como profesional para reservar'
    end
  end

  def booking_created_notice(base = nil)
    parts = []
    parts << base if base.present?
    parts << 'Recuerda completar tu perfil.' unless current_user.profile_complete?
    parts.join(' ').presence
  end

  def set_booking
    @booking = Booking.find(params.expect(:id))
  end

  def load_space_show_vars
    @week_start = Date.current.beginning_of_week(:monday)
    @schedule = AvailabilityScheduleBuilder.new(@space, week_start: @week_start).build
  end

  def booking_params
    params.permit(:date, :start_time, :slot_count, :hours, :reschedule_credit_id, :accept_terms,
                  :reservation_mode, :slot_rate_id)
  end

  def reschedule_params
    params.permit(:date, :start_time, :slot_count, :hours)
  end
end
