# frozen_string_literal: true

module Bookings
  class ApplyDiscountCode
    def initialize(booking:, code:, actor:)
      @booking = booking
      @raw_code = code
      @actor = actor
    end

    def call
      return failure('No puedes aplicar un código en esta reserva') unless applicable?
      return failure('Ingresa un código') if DiscountCode.normalize_code(@raw_code).blank?

      discount_code = DiscountCode.find_by_normalized(@raw_code)
      return failure('Código no válido') unless discount_code
      return failure('Este código no está vigente') unless discount_code.redeemable_at?

      payable_base = payable_amount_before_promo
      promo_cents = discount_code.discount_cents_for(payable_base)
      return failure('Este código no aplica a esta reserva') if promo_cents <= 0

      ApplicationRecord.transaction do
        release_previous_code!
        discount_code.reserve_redemption!
        apply_to_booking!(discount_code, promo_cents, payable_base)
      end

      auto_confirm_if_free!
      Result.new(success: true, booking: @booking.reload)
    rescue ActiveRecord::RecordInvalid
      failure('Este código ya no tiene usos disponibles')
    end

    private

    def applicable?
      return false unless @actor.admin? || @booking.profesional_id == @actor.id

      @booking.pending_payment? && !@booking.payment_expired?
    end

    def payable_amount_before_promo
      @booking.total_amount_cents.to_i + @booking.promo_discount_cents.to_i
    end

    def release_previous_code!
      previous = @booking.discount_code
      return unless previous

      previous.release_redemption!
    end

    def apply_to_booking!(discount_code, promo_cents, payable_base)
      new_total = [payable_base - promo_cents, 0].max
      @booking.update!(
        discount_code: discount_code,
        promo_discount_cents: promo_cents,
        total_amount_cents: new_total
      )
      invalidate_stale_payment_preference!
    end

    def invalidate_stale_payment_preference!
      payment = @booking.payment
      return unless payment&.pending?
      return if payment.amount_cents == @booking.total_amount_cents

      payment.update!(
        mercadopago_preference_id: nil,
        amount_cents: @booking.total_amount_cents
      )
    end

    def auto_confirm_if_free!
      return unless @booking.total_amount_cents.zero?

      @booking.update!(status: :confirmed, payment_expires_at: nil)
    end

    def failure(message)
      Result.new(success: false, errors: [message])
    end

    class Result
      attr_reader :booking, :errors

      def initialize(success:, booking: nil, errors: [])
        @success = success
        @booking = booking
        @errors = errors
      end

      def success?
        @success
      end
    end
  end
end
