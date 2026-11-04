# frozen_string_literal: true

module Admin
  class DiscountCodesController < Admin::BaseController
    before_action :set_discount_code, only: %i[edit update destroy]

    def index
      @discount_codes = DiscountCode.order(created_at: :desc)
      code_ids = @discount_codes.map(&:id)

      @confirmed_bookings_counts =
        if code_ids.empty?
          {}
        else
          Booking.confirmed.where(discount_code_id: code_ids).group(:discount_code_id).count
        end

      space_ids = @discount_codes.flat_map { |code| code.normalized_allowed_space_ids }.uniq
      @space_titles_by_id =
        if space_ids.empty?
          {}
        else
          Space.where(id: space_ids).pluck(:id, :title).to_h
        end
    end

    def new
      @discount_code = DiscountCode.new(
        discount_starts_on: Date.current,
        discount_ends_on: 1.month.from_now.to_date,
        discount_type: :percent,
        percent: 10,
        applies_to_hourly: true,
        applies_to_slot_based: true,
        applies_to_jornada: true
      )
      @spaces = Space.order(:title)
    end

    def edit
      @spaces = Space.order(:title)
    end

    def create
      @discount_code = DiscountCode.new(discount_code_params)

      if @discount_code.save
        redirect_to admin_discount_codes_path, notice: 'Código creado'
      else
        @spaces = Space.order(:title)
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @discount_code.update(discount_code_params)
        redirect_to admin_discount_codes_path, notice: 'Código actualizado'
      else
        @spaces = Space.order(:title)
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @discount_code.bookings.exists?
        redirect_to admin_discount_codes_path, alert: 'No se puede eliminar: hay reservas con este código'
      else
        @discount_code.destroy
        redirect_to admin_discount_codes_path, notice: 'Código eliminado'
      end
    end

    private

    def set_discount_code
      @discount_code = DiscountCode.find(params.expect(:id))
    end

    def discount_code_params
      permitted = params.expect(
        discount_code: [
          :code,
          :discount_type,
          :percent,
          :amount_cents,
          :discount_starts_on,
          :discount_ends_on,
          :active,
          :max_uses,
          :max_uses_per_user,
          :allowed_start_time,
          :allowed_end_time,
          :applies_to_hourly,
          :applies_to_slot_based,
          :applies_to_jornada,
          { allowed_weekdays: [],
            allowed_space_ids: [] }
        ]
      )

      permitted
    end
  end
end
