# frozen_string_literal: true

class BookingMailer < ApplicationMailer
  def booking_confirmed(booking)
    @booking = booking
    mail(to: @booking.profesional.email, subject: "Reserva confirmada — #{@booking.space.title}")
  end

  def payment_rejected(booking)
    @booking = booking
    mail(to: @booking.profesional.email, subject: "Pago rechazado — #{@booking.space.title}")
  end

  def payment_expiring_soon(booking)
    @booking = booking
    mail(to: @booking.profesional.email, subject: "Tu reserva expira pronto — #{@booking.space.title}")
  end

  def booking_cancelled(booking)
    @booking = booking
    mail(to: @booking.profesional.email, subject: "Reserva cancelada — #{@booking.space.title}")
  end
end
