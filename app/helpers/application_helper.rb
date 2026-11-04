# frozen_string_literal: true

module ApplicationHelper
  include Pagy::Frontend
  include LazyImageHelper

  def format_clp(cents)
    Money.new(cents, 'CLP').format(no_cents_if_whole: true)
  end

  def gallery_photo_path(item)
    gallery_path(tag: item.tag_slug, photo_id: item.id)
  end

  def image_loading_attrs(eager: false)
    if eager
      { loading: 'eager', fetchpriority: 'high', decoding: 'async' }
    else
      { loading: 'lazy', fetchpriority: 'low', decoding: 'async' }
    end
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

  def spot_offer_status_label(offer)
    {
      'active' => 'Activa (pendiente de pago)',
      'paid' => 'Pagada',
      'cancelled' => 'Cancelada'
    }.fetch(offer.status, offer.status.humanize)
  end

  def booking_spot_offer_price_badge_label(booking)
    return unless booking.spot_offer_booking?

    index = booking.spot_package_session_index
    count = booking.spot_package_sessions_count
    return if index.blank? || count.zero?

    "Reserva de tarifa particular — ##{booking.id} — #{booking.formatted_spot_package_total} · #{index}/#{count} reservas"
  end

  def booking_spot_offer_price_badge_classes(booking)
    base = 'inline-flex max-w-full flex-wrap items-center rounded-full px-3 py-1 text-xs font-medium'
    if booking.spot_package_paid? || booking.confirmed? || booking.completed?
      "#{base} bg-violet-100 text-violet-900"
    else
      "#{base} bg-violet-50 text-violet-800 ring-1 ring-violet-200"
    end
  end

  def booking_status_label(booking)
    if booking.pending_payment? && booking.reschedule_replacement?
      return 'Reagendamiento pendiente de pago'
    end

    if booking.confirmed? && booking.respond_to?(:manually_confirmed_at) && booking.manually_confirmed_at.present?
      return 'Confirmada manualmente'
    end

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

  def booking_can_leave_testimonial?(booking)
    booking.completed? && booking.testimonial.nil?
  end

  def bookings_index_empty_message(filter)
    {
      'confirmed' => 'No tienes reservas confirmadas.',
      'pending_payment' => 'No tienes reservas pendientes de pago.',
      'cancelled' => 'No tienes reservas canceladas.'
    }.fetch(filter, 'No hay reservas en esta categoría.')
  end

  def google_analytics_id
    SiteSetting.get('google_analytics_id', ENV.fetch('GOOGLE_ANALYTICS_ID', nil))
  end

  def equipment_list(space)
    if space.association(:equipment_items).loaded?
      space.equipment_items.sort_by { |item| [item.position, item.id] }.map(&:name)
    else
      space.equipment_items.ordered.pluck(:name)
    end
  end

  def ga_event_script(event_name, params = {})
    return '' if google_analytics_id.blank?

    payload = params.to_json
    javascript_tag("if (typeof gtag === 'function') { gtag('event', '#{j(event_name)}', #{payload}); }")
  end

  def footer_social_contacts
    @footer_social_contacts ||= SocialContact.visible.ordered.with_attached_icon.to_a
  end

  def whatsapp_url_for_phone(phone)
    digits = phone.to_s.gsub(/\D/, '')
    return '#' if digits.blank?

    "https://wa.me/#{digits}"
  end

  SITE_LOGO_ASSET = 'logo_vital_hub.png'
  # Misma foto que la galería «Recepción» en seeds (vitalhub_office_4.jpg)
  SITE_HERO_FALLBACK_ASSET = 'vitalhub_office_4.jpg'

  def site_navigation_settings
    @site_navigation_settings ||= SiteNavigationSettings.load_all
  end

  def site_logo
    SITE_LOGO_ASSET
  end

  def site_hero_gallery_item
    @site_hero_gallery_item ||= GalleryItem.items_for_tag_slug('recepcion').first
  end

  def site_hero_image
    SITE_HERO_FALLBACK_ASSET
  end

  def site_nav_text(key)
    site_navigation_settings.fetch(key.to_s) { SiteNavigationSettings::DEFAULTS.fetch(key.to_s) }
  end

  def mobile_tab_bar_link_class(active: false, primary: false)
    base = 'flex min-w-0 flex-col items-center justify-center gap-0.5 px-1 text-[10px] font-medium uppercase tracking-wide transition-colors'
    if active
      primary ? "#{base} text-brand-dark" : "#{base} text-brand"
    else
      "#{base} text-gray-500 hover:text-brand"
    end
  end

  def mobile_tab_home_active?
    current_page?(root_path)
  end

  def mobile_tab_sign_in_active?
    controller_path.in?(%w[users/sessions users/registrations users/passwords])
  end

  def mobile_tab_bookings_active?
    controller_name == 'bookings'
  end

  def mobile_tab_reserve_active?
    return false if mobile_tab_bookings_active?

    controller_name.in?(%w[spaces space_checkouts])
  end

  def mobile_tab_profile_active?
    controller_name == 'profiles'
  end

  def mobile_tab_bar_icon(name)
    paths = {
      home: 'M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6',
      reserve: 'M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z',
      sign_in: 'M15 3h4a2 2 0 012 2v14a2 2 0 01-2 2h-4M10 17l5-5m0 0l-5-5m5 5H3',
      bookings: 'M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2',
      profile: 'M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z'
    }
    tag.svg(
      class: 'h-6 w-6 shrink-0',
      width: 24,
      height: 24,
      fill: 'none',
      stroke: 'currentColor',
      'stroke-width': '1.5',
      viewBox: '0 0 24 24',
      aria: { hidden: true }
    ) do
      tag.path('stroke-linecap': 'round', 'stroke-linejoin': 'round', d: paths.fetch(name))
    end
  end

  def site_logo_url
    absolute_url(asset_path(SITE_LOGO_ASSET))
  end

  def site_hero_image_url
    item = site_hero_gallery_item
    if item&.image&.attached?
      absolute_url(url_for(item.image.variant(resize_to_limit: VARIANT_LIMITS_DEFAULT)))
    else
      absolute_url(asset_path(SITE_HERO_FALLBACK_ASSET))
    end
  end

  def home_highlight_icon_svg(icon_key, css_class: 'h-6 w-6')
    definition = HomeHighlightIcons.fetch(icon_key)
    tag.svg(
      class: css_class,
      fill: 'none',
      stroke: 'currentColor',
      'stroke-width': '1.5',
      viewBox: '0 0 24 24',
      aria: { hidden: true }
    ) do
      safe_join(
        definition[:paths].map do |path_data|
          tag.path('stroke-linecap': 'round', 'stroke-linejoin': 'round', d: path_data)
        end
      )
    end
  end
end
