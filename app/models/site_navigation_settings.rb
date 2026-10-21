# frozen_string_literal: true

class SiteNavigationSettings
  DEFAULTS = {
    'nav_announcement' => 'Espacios de salud · Bloques flexibles o día completo · Reserva en línea',
    'nav_link_spaces' => 'Espacios',
    'nav_link_gallery' => 'Galería',
    'nav_link_membership' => 'Membresía',
    'nav_link_bookings' => 'Mis reservas',
    'nav_link_comment' => 'Comentario',
    'nav_link_profile' => 'Perfil',
    'nav_link_admin' => 'Admin',
    'nav_link_reserve' => 'Reservar',
    'nav_link_sign_out' => 'Salir',
    'nav_link_sign_in' => 'Ingresar',
    'footer_tagline' => 'Arriendo de espacio profesional para salud. Bloques flexibles o día completo en Chile.',
    'footer_nav_heading' => 'Navegación',
    'footer_link_spaces' => 'Espacios',
    'footer_link_membership' => 'Membresía',
    'footer_link_terms' => 'Términos',
    'footer_link_privacy' => 'Privacidad',
    'footer_link_cancellation' => 'Cancelaciones',
    'footer_contact_heading' => 'Contacto',
    'footer_contact_line' => 'Espacios de salud · VitalHub',
    'footer_copyright' => 'VitalHub. Chile.'
  }.freeze

  LABELS = {
    'nav_announcement' => 'Barra superior (anuncio)',
    'nav_link_spaces' => 'Enlace: Espacios',
    'nav_link_gallery' => 'Enlace: Galería',
    'nav_link_membership' => 'Enlace: Membresía',
    'nav_link_bookings' => 'Enlace: Mis reservas',
    'nav_link_comment' => 'Enlace: Comentario (usuarios con reserva)',
    'nav_link_profile' => 'Enlace: Perfil',
    'nav_link_admin' => 'Enlace: Admin',
    'nav_link_reserve' => 'Botón: Reservar',
    'nav_link_sign_out' => 'Enlace: Salir',
    'nav_link_sign_in' => 'Enlace: Ingresar',
    'footer_tagline' => 'Pie: descripción breve',
    'footer_nav_heading' => 'Pie: título sección navegación',
    'footer_link_spaces' => 'Pie: enlace Espacios',
    'footer_link_membership' => 'Pie: enlace Membresía',
    'footer_link_terms' => 'Pie: enlace Términos',
    'footer_link_privacy' => 'Pie: enlace Privacidad',
    'footer_link_cancellation' => 'Pie: enlace Cancelaciones',
    'footer_contact_heading' => 'Pie: título contacto',
    'footer_contact_line' => 'Pie: línea de contacto',
    'footer_copyright' => 'Pie: texto copyright (después del año)'
  }.freeze

  KEYS = LABELS.keys.freeze
  CACHE_KEY = 'site_navigation_settings/v1'

  def self.load_all
    Rails.cache.fetch(CACHE_KEY, expires_in: 5.minutes) do
      stored = SiteSetting.where(key: KEYS).pluck(:key, :value).to_h
      KEYS.index_with { |key| stored[key].presence || DEFAULTS.fetch(key) }
    end
  end

  def self.value(key)
    load_all.fetch(key.to_s) { DEFAULTS.fetch(key.to_s) }
  end
end
