# frozen_string_literal: true

# Ruta deprecada: /spaces/:id/checkout. Redirige al espacio con parámetros de reserva.
class SpaceCheckoutsController < ApplicationController
  def show
    load_checkout_context!
    target = helpers.space_booking_prefill_path(@space, **@checkout_params)

    unless policy(@space).checkout?
      store_location_for(:user, target) unless user_signed_in?
      redirect_to target,
                  alert: ('Inicia sesión o regístrate para reservar' unless user_signed_in?),
                  status: :see_other
      return
    end

    raise 'Space checkout UI removed; policy should deny checkout?'
  end

  private

  def load_checkout_context!
    @space = Space.published_spaces
                  .includes(:slot_rates, :jornada_definitions, space_photos: { image_attachment: :blob })
                  .find(params.expect(:id))
    authorize @space, :show?

    @checkout_params = normalized_checkout_params
  end

  def normalized_checkout_params
    raw = params.permit(:date, :start_time, :slot_count, :hours, :reservation_mode, :slot_rate_id,
                        rented_equipment_item_ids: []).to_h
    available_modes = helpers.space_checkout_mode_values(@space)
    mode = raw['reservation_mode'].presence || 'hora'
    mode = 'hora' unless available_modes.include?(mode)
    date = parse_date(raw['date']) || @space.first_bookable_date

    defaults = {
      'reservation_mode' => mode,
      'date' => date.iso8601,
      'slot_count' => (@space.minimum_slots if mode == 'hora')
    }.compact

    merged = defaults.merge(raw.stringify_keys)
    merged['slot_count'] ||= merged['hours'] if merged['hours'].present?

    if mode == 'hora' && merged['start_time'].blank?
      options = helpers.space_booking_start_time_options(@space, date)
      merged['start_time'] = options.first&.last
    end

    if mode == 'bloque' && merged['slot_rate_id'].blank?
      merged['slot_rate_id'] = @space.bloque_slot_rates.first&.id&.to_s
    end

    merged
  end

  def parse_date(value)
    return value.to_date if value.present?

    nil
  rescue ArgumentError
    nil
  end
end
