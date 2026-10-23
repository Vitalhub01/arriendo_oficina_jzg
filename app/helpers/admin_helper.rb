# frozen_string_literal: true

module AdminHelper
  NAV_ITEMS = [
    { label: 'Dashboard', path: :admin_root_path, match: ->(req) { req.path == '/admin' } },
    { label: 'Oficina', path: :edit_admin_office_path, match: ->(req) { req.path.start_with?('/admin/office') } },
    { label: 'Espacios', path: :admin_spaces_path, match: ->(req) { req.path.start_with?('/admin/spaces') } },
    {
      label: 'Descuentos membresía',
      path: :admin_pricing_rules_path,
      match: ->(req) { req.path.start_with?('/admin/pricing_rules') },
      feature: :memberships
    },
    {
      label: 'Códigos de descuento',
      path: :admin_discount_codes_path,
      match: ->(req) { req.path.start_with?('/admin/discount_codes') }
    },
    { label: 'Usuarios y permisos', path: :admin_users_path, match: ->(req) { req.path.start_with?('/admin/users') } },
    {
      label: 'Profesionales',
      path: :admin_professionals_path,
      match: ->(req) { req.path.start_with?('/admin/professionals') }
    },
    {
      label: 'Tarifas spot',
      path: :admin_spot_offers_path,
      match: ->(req) { req.path.start_with?('/admin/spot_offers') }
    },
    {
      label: 'Reservas',
      match: ->(req) { req.path.start_with?('/admin/bookings') },
      children: [
        {
          label: 'Lista',
          path: :admin_bookings_path,
          match: ->(req) { req.path == '/admin/bookings' }
        },
        {
          label: 'Calendario',
          path: :calendar_admin_bookings_path,
          match: ->(req) { req.path == '/admin/bookings/calendar' }
        },
        {
          label: 'Contactos del día',
          path: :day_contacts_admin_bookings_path,
          match: ->(req) { req.path == '/admin/bookings/day_contacts' }
        }
      ]
    },
    {
      label: 'Membresías',
      path: :admin_memberships_path,
      match: ->(req) { req.path.start_with?('/admin/memberships') },
      feature: :memberships
    },
    {
      label: 'Planes membresía',
      path: :admin_membership_plans_path,
      match: ->(req) { req.path.start_with?('/admin/membership_plans') },
      feature: :memberships
    },
    {
      label: 'Testimonios',
      path: :admin_testimonials_path,
      match: ->(req) { req.path.start_with?('/admin/testimonials') }
    },
    { label: 'FAQ', path: :admin_faqs_path, match: ->(req) { req.path.start_with?('/admin/faqs') } },
    {
      label: 'Galería inicio',
      path: :admin_gallery_items_path,
      match: ->(req) { req.path == '/admin/gallery' || req.path == '/admin/gallery/reorder' || req.path.match?(%r{^/admin/gallery/\d+}) }
    },
    {
      label: 'Destacados inicio',
      path: :admin_home_highlights_path,
      match: ->(req) { req.path.start_with?('/admin/home-highlights') }
    },
    {
      label: 'Descripciones de galería',
      path: :admin_gallery_tags_path,
      match: ->(req) { req.path.start_with?('/admin/gallery-tags') }
    },
    {
      label: 'Redes sociales',
      path: :admin_social_contacts_path,
      match: ->(req) { req.path.start_with?('/admin/social_contacts') }
    },
    {
      label: 'Configuración',
      path: :edit_admin_site_settings_path,
      match: ->(req) { req.path.start_with?('/admin/site_settings') }
    }
  ].freeze

  def admin_nav_items
    NAV_ITEMS.select do |item|
      item[:feature] != :memberships || memberships_enabled?
    end
  end

  def admin_nav_link_classes(active, nested: false)
    base = 'block rounded-lg text-sm transition'
    base += nested ? ' px-3 py-1.5 pl-6' : ' px-3 py-2'
    if active
      "#{base} bg-brand font-medium text-white"
    else
      "#{base} text-white/90 hover:bg-gray-800 hover:text-white"
    end
  end

  def admin_nav_section_label_classes(active)
    base = 'px-3 py-2 text-xs font-semibold uppercase tracking-wide'
    active ? "#{base} text-white" : "#{base} text-white/60"
  end

  def admin_nav_active?(match_proc)
    match_proc.call(request)
  end

  def admin_booking_calendar_slot_classes(status)
    {
      available: 'border-green-300 bg-green-100 text-green-900',
      pending: 'border-amber-300 bg-amber-100 text-amber-950',
      blocked: 'border-gray-300 bg-gray-200 text-gray-600',
      confirmed: 'border-blue-300 bg-blue-100 text-blue-950'
    }.fetch(status.to_sym, 'border-gray-200 bg-white text-gray-800')
  end
end
