# frozen_string_literal: true

class BookingsController < ApplicationController
  include SpaceScheduleWeeks

  before_action :authenticate_user!
  before_action :require_can_book!, only: %i[new create reschedule]
  before_action :set_booking, only: %i[show checkout cancel reschedule apply_discount_code]

  BOOKING_INDEX_FILTERS = {
    'confirmed' => { label: 'Confirmadas', statuses: %i[confirmed completed] },
    'pending_payment' => { label: 'Pendientes de pago', statuses: %i[pending_payment] },
    'cancelled' => { label: 'Canceladas', statuses: %i[cancelled rescheduled] }
  }.freeze

  def index
    @filter = BOOKING_INDEX_FILTERS.key?(params[:filter]) ? params[:filter] : 'confirmed'
    base_scope = policy_scope(Booking).includes(:space, :payment, :testimonial)
    statuses = BOOKING_INDEX_FILTERS.fetch(@filter)[:statuses]
    @filter_counts = booking_index_filter_counts(base_scope)

    @pagy, @bookings = pagy(
      base_scope.where(status: statuses).order(start_at: :desc)
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
      elsif params[:from_checkout].present? && result.booking.pending_payment? && result.booking.total_amount_cents.positive?
        redirect_to checkout_booking_path(result.booking), notice: booking_created_notice, status: :see_other
      else
        redirect_to result.booking, notice: booking_created_notice, status: :see_other
      end
    else
      if params[:from_checkout].present?
        redirect_to checkout_space_path(@space, checkout_return_params), alert: result.errors.join(', ')
      else
        load_space_show_vars
        @errors = result.errors
        render 'spaces/show', status: :unprocessable_content
      end
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
    load_space_schedule(@space)
  end

  def booking_params
    params.permit(:date, :start_time, :slot_count, :hours, :reschedule_credit_id, :accept_terms,
                  :reservation_mode, :slot_rate_id, :from_checkout, rented_equipment_item_ids: [])
  end

  def checkout_return_params
    booking_params.except(:from_checkout, :accept_terms, :reschedule_credit_id)
  end

  def reschedule_params
    params.permit(:date, :start_time, :slot_count, :hours)
  end

  def booking_index_filter_counts(scope)
    BOOKING_INDEX_FILTERS.transform_values do |config|
      scope.where(status: config[:statuses]).count
    end
  end
end
