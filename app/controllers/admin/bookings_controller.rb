# frozen_string_literal: true

module Admin
  class BookingsController < Admin::BaseController
    before_action :set_booking, only: %i[show update]

    def index
      scope = Booking.includes(:space, :profesional, :payment).order(start_at: :desc)
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where(box_id: params[:space_id]) if params[:space_id].present?
      @pagy, @bookings = pagy(scope)
    end

    def show; end

    def new
      @professionals = bookable_professionals
      @spaces = Space.includes(:office).order(:title)
      @booking = Booking.new
    end

    def create
      @professionals = bookable_professionals
      @spaces = Space.includes(:office).order(:title)

      space = Space.find_by(id: create_params[:space_id])
      profesional = User.find_by(id: create_params[:profesional_id])

      unless space && profesional && bookable_professionals.exists?(profesional.id)
        flash.now[:alert] = 'Selecciona un espacio y un profesional válidos'
        @booking = Booking.new
        return render :new, status: :unprocessable_content
      end

      result = Bookings::Create.new(
        space: space,
        profesional: profesional,
        params: create_params.slice(:date, :start_time, :slot_count, :hours)
      ).call

      if result.success?
        booking = result.booking
        if ActiveModel::Type::Boolean.new.cast(create_params[:confirm_manually]) && booking.pending_payment?
          confirm = Bookings::ConfirmManually.new(booking: booking, actor: current_user).call
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
        render :new, status: :unprocessable_content
      end
    end

    def update
      if params[:cancel].present?
        result = Bookings::Cancel.new(booking: @booking, actor: current_user).call
        flash_key = result.success? ? :notice : :alert
        flash[flash_key] = result.success? ? 'Reserva anulada' : result.errors.join(', ')
      elsif params[:confirm_manually].present?
        result = Bookings::ConfirmManually.new(booking: @booking, actor: current_user).call
        flash_key = result.success? ? :notice : :alert
        flash[flash_key] = result.success? ? 'Reserva confirmada manualmente' : result.errors.join(', ')
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
      @booking = Booking.find(params.expect(:id))
    end

    def bookable_professionals
      User.where(role: %i[profesional profesional_suscrito]).order(:name)
    end

    def create_params
      params.expect(booking: %i[space_id profesional_id date start_time slot_count hours confirm_manually])
    end
  end
end
