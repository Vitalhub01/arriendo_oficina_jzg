# frozen_string_literal: true

module SpotOffers
  class ConfirmManually
    def initialize(spot_offer:, actor:)
      @spot_offer = spot_offer
      @actor = actor
    end

    def confirmable?
      return false unless @actor.admin?
      return false unless @spot_offer.active?
      return false if @spot_offer.bookings.empty?

      pending = @spot_offer.bookings.pending_payment
      return false unless pending.count == @spot_offer.bookings.count

      pending.none?(&:payment_expired?)
    end

    def call
      return failure('Solo un administrador puede confirmar manualmente') unless @actor.admin?
      return failure('Esta oferta ya fue pagada o cancelada') unless @spot_offer.active?
      return failure('No hay reservas asociadas a este paquete') if @spot_offer.bookings.empty?

      pending = @spot_offer.bookings.pending_payment.to_a
      if pending.size != @spot_offer.bookings.size
        return failure('Confirma el paquete completo: hay reservas que ya no están pendientes de pago')
      end
      return failure('Una o más reservas superaron el plazo de pago') if pending.any?(&:payment_expired?)

      ActiveRecord::Base.transaction do
        pending.each do |booking|
          booking.update!(
            status: :confirmed,
            payment_expires_at: nil,
            manually_confirmed_at: Time.current
          )
          Bookings::FinalizeReschedule.new(booking: booking).call
          BookingMailer.booking_confirmed(booking).deliver_later
        end

        payment = @spot_offer.payment || Payment.new(
          spot_offer: @spot_offer,
          payer: @spot_offer.profesional,
          payment_kind: :spot_offer
        )
        payment.assign_attributes(
          amount_cents: @spot_offer.total_price_cents,
          status: :approved
        )
        payment.payer ||= @spot_offer.profesional
        payment.save!

        @spot_offer.update!(status: :paid)
        GenerateInvoiceJob.perform_later(payment.id) if payment.approved?
      end

      Result.new(success: true)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(', '))
    end

    private

    def failure(message)
      Result.new(success: false, errors: [message])
    end

    class Result
      attr_reader :errors

      def initialize(success:, errors: [])
        @success = success
        @errors = errors
      end

      def success?
        @success
      end
    end
  end
end
