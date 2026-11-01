# frozen_string_literal: true

module Admin
  class BookingsController < Admin::BaseController
    include SpaceScheduleWeeks

    before_action :set_booking, only: %i[show update]

    def index
      scope = Booking.includes(:space, :profesional, :payment).without_spot_offer.order(created_at: :desc)
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where(box_id: params[:space_id]) if params[:space_id].present?
      @pagy, @bookings = pagy(scope)
    end

    def calendar
      @spaces = Space.order(:title)
      @week_start = parse_week_start
      @calendar_space = Space.find_by(id: params[:space_id]) || @spaces.first
      return unless @calendar_space

      @calendar_days = ::Bookings::AdminCalendarBuilder.new(
        space: @calendar_space,
        week_start: @week_start
      ).build
    end

    def day_contacts
      @date = parse_contact_date
      bookings = Booking.includes(:space, :profesional)
                        .starting_on_date(@date)
                        .excluding_cancelled
                        .order(:start_at)
      @bookings_by_user = bookings.group_by(&:profesional)

      respond_to do |format|
        format.html
        format.csv { send_day_contacts_csv(@date, @bookings_by_user) }
      end
    end

    def show; end

    def new
      @professionals = bookable_professionals
      @spaces = Space.includes(:office).order(:title)
      @booking = Booking.new
      @booking_form_params = booking_form_params
      prepare_admin_booking_schedule
    end

    def schedule
      @selected_space = Space.find(params.expect(:space_id))
      load_admin_space_schedule(@selected_space)

      render partial: 'admin/bookings/schedule_frame',
             locals: schedule_frame_locals
    end

    def availability
      @selected_space = Space.find(params.expect(:space_id))
      load_admin_space_schedule(@selected_space)

      render json: @availability_schedule_payload
    end

    def create
      @professionals = bookable_professionals
      @spaces = Space.includes(:office).order(:title)
      @booking_form_params = booking_form_params

      space = Space.find_by(id: create_params[:space_id])
      profesional = User.find_by(id: create_params[:profesional_id])

      unless space && profesional && bookable_professionals.exists?(profesional.id)
        flash.now[:alert] = 'Selecciona un espacio y un profesional válidos'
        @booking = Booking.new
        prepare_admin_booking_schedule(space)
        return render :new, status: :unprocessable_content
      end

      result = ::Bookings::Create.new(
        space: space,
        profesional: profesional,
        params: create_params.slice(:date, :start_time, :slot_count, :hours, :reservation_mode, :slot_rate_id),
        require_terms_acceptance: false
      ).call

      if result.success?
        booking = result.booking
        if ActiveModel::Type::Boolean.new.cast(create_params[:confirm_manually]) && booking.pending_payment?
          confirm = ::Bookings::ConfirmManually.new(booking: booking, actor: current_user).call
          unless confirm.success?
            flash[:alert] = "Reserva creada pero no se pudo confirmar: #{confirm.errors.join(', ')}"
            redirect_to admin_booking_path(booking)
            return
          end
          booking.reload
        end

        redirect_to admin_booking_path(booking), notice: 'Reserva creada'
      else
        flash.now[:alert] = result.errors.join(', ')
        @booking = Booking.new
        prepare_admin_booking_schedule(space)
        render :new, status: :unprocessable_content
      end
    end

    def update
      if params[:cancel].present?
        result = ::Bookings::Cancel.new(booking: @booking, actor: current_user).call
        flash_key = result.success? ? :notice : :alert
        flash[flash_key] = result.success? ? 'Reserva anulada' : result.errors.join(', ')
      elsif params[:confirm_manually].present?
        result = ::Bookings::ConfirmManually.new(booking: @booking, actor: current_user).call
        flash_key = result.success? ? :notice : :alert
        flash[flash_key] = result.success? ? 'Reserva confirmada manualmente' : result.errors.join(', ')
      elsif params[:verify_profesional].present?
        @booking.profesional.update!(professional_verified_at: Time.current)
        flash[:notice] = 'Profesional marcado como verificado'
      elsif params[:unverify_profesional].present?
        @booking.profesional.update!(professional_verified_at: nil)
        flash[:notice] = 'Verificación de profesional revocada'
      elsif params[:ban_profesional].present?
        if @booking.profesional_id == current_user.id
          flash[:alert] = 'No puedes bloquear tu propia cuenta'
        else
          @booking.profesional.update!(banned_at: Time.current)
          flash[:notice] = 'Profesional agregado a la lista negra'
        end
      elsif params[:unban_profesional].present?
        @booking.profesional.update!(banned_at: nil)
        flash[:notice] = 'Profesional reactivado'
      end

      redirect_to admin_booking_path(@booking)
    end

    private

    def set_booking
      @booking = Booking.includes(spot_offer: :bookings).find(params.expect(:id))
    end

    def bookable_professionals
      User.where(role: %i[profesional profesional_suscrito]).order(:name)
    end

    def create_params
      params.expect(booking: %i[
                      space_id profesional_id date start_time slot_count hours confirm_manually
                      reservation_mode slot_rate_id
                    ])
    end

    def prepare_admin_booking_schedule(space = nil)
      space_id = space&.id || params.dig(:booking, :space_id).presence || params[:space_id].presence
      @selected_space = Space.includes(:office, :slot_rates, :jornada_definitions, :schedule_blocks)
                             .find_by(id: space_id)
      return unless @selected_space

      load_admin_space_schedule(@selected_space)
    end

    def load_admin_space_schedule(space)
      @week_start = schedule_week_start(space)
      @schedule_week_entries = AvailabilityScheduleBuilder.new(
        space,
        week_start: @week_start,
        week_count: SpaceScheduleWeeks::PRELOAD_WEEKS,
        exclude_renter_id: nil
      ).build_weeks
      @availability_schedule_payload = SpaceAvailabilitySchedulePresenter.new(
        space: space,
        schedule_week_entries: @schedule_week_entries,
        week_start: @week_start,
        interactive: true,
        login_prompt_on_slots: false
      ).as_json
    end

    def schedule_frame_locals
      {
        selected_space: @selected_space,
        week_start: @week_start,
        schedule_payload: @availability_schedule_payload,
        booking_params: booking_form_params
      }
    end

    def booking_form_params
      raw = params[:booking]
      return {} unless raw.respond_to?(:permit)

      raw.permit(:date, :start_time, :slot_count, :reservation_mode, :slot_rate_id).to_h
    end

    def availability_schedule_interactive?
      true
    end

    def availability_schedule_login_prompt?
      false
    end

    def parse_week_start
      if params[:week_start].present?
        Date.parse(params[:week_start]).beginning_of_week(:monday)
      else
        Date.current.beginning_of_week(:monday)
      end
    end

    def parse_contact_date
      if params[:date].present?
        Date.parse(params[:date])
      else
        Date.current
      end
    end

    def send_day_contacts_csv(date, bookings_by_user)
      require 'csv'
      csv = CSV.generate(headers: true) do |rows|
        rows << %w[nombre email verificado_profesional reservas espacios]
        bookings_by_user.each do |user, user_bookings|
          rows << [
            user.name,
            user.email,
            user.professional_identity_verified? ? 'si' : 'no',
            user_bookings.size,
            user_bookings.map { |b| b.space.title }.uniq.join('; ')
          ]
        end
      end
      send_data csv, filename: "reservas-#{date.iso8601}.csv", type: 'text/csv; charset=utf-8'
    end
  end
end
