# frozen_string_literal: true

module SpotOffers
  class Checkout
    def initialize(spot_offer:, profesional:)
      @spot_offer = spot_offer
      @profesional = profesional
    end

    def call
      return failure('Esta oferta ya no está disponible') unless @spot_offer.active?
      return failure('Debes iniciar sesión') unless @profesional

      occurrences = BuildOccurrences.new(
        space: @spot_offer.space,
        starts_on: @spot_offer.starts_on,
        ends_on: @spot_offer.ends_on,
        daily_start_time: @spot_offer.daily_start_time,
        daily_end_time: @spot_offer.daily_end_time
      ).call

      return failure('No hay horarios disponibles para esta oferta') if occurrences.empty?

      ActiveRecord::Base.transaction do
        @spot_offer.bookings.pending_payment.destroy_all
        per_booking_cents = split_amount(@spot_offer.total_price_cents, occurrences.size)

        occurrences.each_with_index do |occurrence, index|
          @spot_offer.space.bookings.create!(
            profesional: @profesional,
            spot_offer: @spot_offer,
            start_at: occurrence[:start_at],
            end_at: occurrence[:end_at],
            duration_minutes: ((occurrence[:end_at] - occurrence[:start_at]) / 60).to_i,
            booking_type: :hourly,
            status: :pending_payment,
            total_amount_cents: per_booking_cents[index],
            discount_cents: 0,
            pricing_breakdown: { spot_offer_id: @spot_offer.id }
          )
        end

        @spot_offer.update!(occurrence_count: occurrences.size, profesional: @profesional)
      end

      payment_result = Payments::MercadoPago::CreateSpotOfferPreference.new(
        spot_offer: @spot_offer,
        payer: @profesional
      ).call

      return Result.new(success: true, init_point: payment_result.init_point) if payment_result.success?

      @spot_offer.bookings.pending_payment.destroy_all
      failure(payment_result.error)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(', '))
    end

    private

    def split_amount(total_cents, count)
      base = total_cents / count
      remainder = total_cents % count
      Array.new(count, base).tap do |amounts|
        amounts[-1] += remainder if remainder.positive?
      end
    end

    def failure(message)
      Result.new(success: false, error: message)
    end

    class Result
      attr_reader :error, :init_point

      def initialize(success:, error: nil, init_point: nil)
        @success = success
        @error = error
        @init_point = init_point
      end

      def success?
        @success
      end
    end
  end
end
