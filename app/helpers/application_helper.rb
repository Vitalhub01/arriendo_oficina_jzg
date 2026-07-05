# frozen_string_literal: true

module ApplicationHelper
  include Pagy::Frontend

  def format_clp(cents)
    Money.new(cents, 'CLP').format(no_cents_if_whole: true)
  end

  def space_type_label(type)
    Space::BOX_TYPE_LABELS[type.to_s] || type
  end

  def amenity_label(key)
    {
      'wifi' => 'WiFi',
      'bathroom' => 'Baño',
      'parking' => 'Estacionamiento',
      'air_conditioning' => 'Aire acondicionado',
      'waiting_room' => 'Sala de espera',
      'wheelchair_access' => 'Acceso silla de ruedas'
    }[key] || key.humanize
  end

  def maps_directions_url(record)
    "https://www.google.com/maps/dir/?api=1&destination=#{record.latitude},#{record.longitude}"
  end

  def waze_url(record)
    "https://waze.com/ul?ll=#{record.latitude},#{record.longitude}&navigate=yes"
  end

  def booking_status_label(booking)
    I18n.t("activerecord.enums.booking.status.#{booking.status}", default: booking.status.humanize)
  end

  def booking_payment_expires_label(booking)
    return unless booking.pending_payment? && booking.payment_expires_at.present?

    if booking.payment_expired?
      'Plazo de pago vencido'
    else
      "Paga antes de #{l(booking.payment_expires_at, format: :short)}"
    end
  end

  def search_city_options
    [['Todas', '']] + Space.published_spaces.distinct.order(:city).pluck(:city).compact.map { |c| [c, c] }
  end

  def search_commune_options
    [['Todas', '']] + Space.published_spaces.distinct.order(:commune).pluck(:commune).compact.map { |c| [c, c] }
  end

  def search_advanced_filters_open?
    params[:start_time].present? || params[:hours].present? ||
      params[:min_price].present? || params[:max_price].present?
  end

  def booking_status_badge_classes(booking)
    case booking.status
    when 'confirmed' then 'bg-green-100 text-green-800'
    when 'pending_payment' then 'bg-amber-100 text-amber-800'
    when 'cancelled' then 'bg-red-100 text-red-800'
    when 'rescheduled' then 'bg-blue-100 text-blue-800'
    else 'bg-gray-100 text-gray-800'
    end
  end

  def google_analytics_id
    SiteSetting.get('google_analytics_id', ENV.fetch('GOOGLE_ANALYTICS_ID', nil))
  end

  def equipment_list(space)
    Array(space.equipment).reject(&:blank?)
  end

  def ga_event_script(event_name, params = {})
    return '' if google_analytics_id.blank?

    payload = params.to_json
    javascript_tag("if (typeof gtag === 'function') { gtag('event', '#{j(event_name)}', #{payload}); }")
  end
end
