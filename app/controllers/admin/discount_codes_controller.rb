# frozen_string_literal: true

module Admin
  class DiscountCodesController < Admin::BaseController
    before_action :set_discount_code, only: %i[edit update destroy]

    def index
      @discount_codes = DiscountCode.order(created_at: :desc)
    end

    def new
      @discount_code = DiscountCode.new(
        starts_at: Time.zone.now.beginning_of_day,
        ends_at: 1.month.from_now.end_of_day,
        discount_type: :percent,
        percent: 10
      )
    end

    def edit; end

    def create
      @discount_code = DiscountCode.new(discount_code_params)

      if @discount_code.save
        redirect_to admin_discount_codes_path, notice: 'Código creado'
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @discount_code.update(discount_code_params)
        redirect_to admin_discount_codes_path, notice: 'Código actualizado'
      else
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
      params.expect(
        discount_code: %i[
          code
          discount_type
          percent
          amount_cents
          starts_at
          ends_at
          active
          max_uses
        ]
      )
    end
  end
end
