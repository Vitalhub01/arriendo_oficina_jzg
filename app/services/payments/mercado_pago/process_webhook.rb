# frozen_string_literal: true

module Payments
  module MercadoPago
    class ProcessWebhook
      APPROVED_STATUSES = %w[approved authorized].freeze

      def initialize(params)
        @params = params
      end

      def call
        payment_id = @params.dig('data', 'id') || @params['id']
        return false unless payment_id

        mp_payment = fetch_payment(payment_id)
        external_reference = mp_payment&.dig('external_reference') || @params['external_reference']
        return false unless external_reference

        if external_reference.start_with?('membership-')
          process_membership_payment(external_reference, payment_id, mp_payment)
        else
          process_booking_payment(external_reference, payment_id, mp_payment)
        end
      end

      private

      def process_booking_payment(booking_id, payment_id, mp_payment)
        booking = Booking.find_by(id: booking_id)
        return false unless booking

        payment = booking.payment || Payment.new(booking: booking, payer: booking.profesional, payment_kind: :booking)
        payment.mercadopago_payment_id = payment_id.to_s
        payment.raw_webhook = @params
        payment.amount_cents ||= booking.total_amount_cents

        status = mp_payment&.dig('status') || @params.dig('data', 'status') || @params['status']
        if APPROVED_STATUSES.include?(status)
          payment.status = :approved
          booking.update!(status: :confirmed, payment_expires_at: nil)
          BookingMailer.booking_confirmed(booking).deliver_later
        elsif status == 'rejected'
          payment.status = :rejected
          BookingMailer.payment_rejected(booking).deliver_later
        end

        payment.save!
        GenerateInvoiceJob.perform_later(payment.id) if payment.approved?
        true
      end

      def process_membership_payment(external_reference, payment_id, mp_payment)
        membership_id = external_reference.delete_prefix('membership-')
        membership = Membership.find_by(id: membership_id)
        return false unless membership

        payment = Payment.find_by(membership: membership, payment_kind: :membership) ||
                  Payment.new(membership: membership, payer: membership.user, payment_kind: :membership)
        payment.mercadopago_payment_id = payment_id.to_s
        payment.raw_webhook = @params
        payment.amount_cents ||= membership.membership_plan.price_cents

        status = mp_payment&.dig('status') || @params.dig('data', 'status')
        if APPROVED_STATUSES.include?(status)
          payment.status = :approved
          membership.update!(status: :active, mercadopago_payment_id: payment_id.to_s)
          membership.user.update!(role: :profesional_suscrito)
        else
          payment.status = :rejected
          membership.update!(status: :cancelled)
        end

        payment.save!
        true
      end

      def fetch_payment(payment_id)
        return if access_token.blank?

        sdk = ::Mercadopago::SDK.new(access_token)
        response = sdk.payment.get(payment_id)
        response[:response]
      rescue StandardError
        nil
      end

      def access_token
        ENV.fetch('MERCADOPAGO_ACCESS_TOKEN', nil)
      end
    end
  end
end
