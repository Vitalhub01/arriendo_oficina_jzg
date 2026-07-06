# frozen_string_literal: true

require 'open-uri'

Rails.logger.debug 'Seeding Oficina JZG...'

admin = User.find_or_create_by!(email: 'admin@jzg.cl') do |u|
  u.name = 'Administrador JZG'
  u.password = 'password123'
  u.role = :admin
end

profesional = User.find_or_create_by!(email: 'profesional@jzg.cl') do |u|
  u.name = 'María Psicóloga'
  u.password = 'password123'
  u.role = :profesional
end

ProfessionalProfile.find_or_create_by!(user: profesional) do |p|
  p.rut = '12345678-5'
  p.validation_status = :manual_verified
  p.onboarding_completed = true
  p.age = 35
  p.gender = 'F'
  p.interested_in_networking = true
end

office = Office.find_or_create_by!(name: 'Oficina JZG') do |o|
  o.description = 'Espacio profesional para psicólogos y terapeutas. Dos boxes de atención y sala de reuniones ' \
                  'totalmente equipados, con excelente ubicación y ambiente acogedor.'
  o.address = 'Av. Providencia 1234, oficina 23'
  o.commune = 'Providencia'
  o.city = 'Santiago'
  o.latitude = -33.4264
  o.longitude = -70.6156
end

placeholder_url = 'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=800&q=80'

spaces_data = [
  {
    title: 'Box de Atención 1',
    box_type: :clinical,
    price: 6_000,
    capacity: 2,
    dimensions: '8m²',
    equipment: %w[Sillón Té WiFi Timbre independiente Iluminación regulable]
  },
  {
    title: 'Box de Atención 2',
    box_type: :clinical,
    price: 6_000,
    capacity: 2,
    dimensions: '10m²',
    equipment: %w[Sillón Camilla Té WiFi Timbre independiente]
  },
  {
    title: 'Sala de Reuniones',
    box_type: :workspace,
    price: 8_000,
    capacity: 10,
    dimensions: '15m²',
    equipment: %w[Pizarra Proyector Mesa WiFi Té]
  }
]

  spaces_data.each do |data|
  space = Space.find_or_initialize_by(title: data[:title], office: office)
  space.assign_attributes(
    description: 'Espacio profesional equipado para atención por bloques configurables.',
    address: office.address,
    commune: office.commune,
    city: office.city,
    latitude: office.latitude,
    longitude: office.longitude,
    box_type: data[:box_type],
    price_per_hour_cents: data[:price],
    minimum_hours: 1,
    slot_duration_minutes: 60,
    minimum_slots: 1,
    status: :draft,
    capacity: data[:capacity],
    dimensions: data[:dimensions],
    equipment: data[:equipment],
    amenities: { 'wifi' => true, 'bathroom' => true, 'air_conditioning' => true, 'waiting_room' => true }
  )
  space.save!

  unless space.photos.attached?
    space.photos.attach(
      io: URI.open(placeholder_url),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )
  end

  space.update!(status: :published)

  (0..4).each do |d|
    AvailabilityRule.find_or_create_by!(box_id: space.id, day_of_week: d) do |rule|
      rule.start_time = Time.zone.parse('2000-01-01 08:00')
      rule.end_time = Time.zone.parse('2000-01-01 20:00')
    end
  end

  [
    { name: 'Mañana', start: '08:00', end: '13:00', price: 12_500 },
    { name: 'Tarde', start: '14:00', end: '19:00', price: 15_000 }
  ].each_with_index do |rate, i|
    SlotRate.find_or_create_by!(space: space, name: rate[:name]) do |sr|
      sr.start_time = Time.zone.parse("2000-01-01 #{rate[:start]}")
      sr.end_time = Time.zone.parse("2000-01-01 #{rate[:end]}")
      sr.price_per_slot_cents = rate[:price]
      sr.position = i
    end
  end
end

PricingRule.find_or_create_by!(name: 'Descuento por volumen') do |r|
  r.rule_type = :volume_discount
  r.config = { 'min_slots' => 4, 'discount_percent' => 10 }
  r.active = true
  r.priority = 10
end

PricingRule.find_or_create_by!(name: 'Descuento membresía') do |r|
  r.rule_type = :membership_discount
  r.config = { 'discount_percent' => 15 }
  r.active = true
  r.priority = 20
end

MembershipPlan.find_or_create_by!(name: 'Membresía Profesional') do |p|
  p.description = 'Acceso a descuentos, capacitaciones y beneficios exclusivos.'
  p.benefits = "• 15% descuento en arriendos\n• Capacitaciones mensuales\n• Acceso a eventos exclusivos"
  p.price_cents = 29_900
  p.billing_period = :monthly
  p.discount_percent = 15
  p.active = true
end

[
  ['¿Hay estacionamiento?', 'Hay alternativas de estacionamiento cercanas sin costo en las calles aledañas.'],
  ['¿Puedo reagendar si mi paciente cancela?', 'Sí, con al menos 24 horas de anticipación puedes reagendar usando un crédito para una reserva futura. No hay reembolso en efectivo.'],
  ['¿Hay WiFi?', 'Contamos con conexión WiFi estable para sesiones online.']
].each_with_index do |(q, a), i|
  Faq.find_or_create_by!(question: q) do |f|
    f.answer = a
    f.position = i
    f.visible = true
  end
end

SiteSetting.set('reschedule_notice_hours', '24')
SiteSetting.set('google_analytics_id', ENV.fetch('GOOGLE_ANALYTICS_ID', ''))

space = Space.first
if space && Booking.where(renter_id: profesional.id).none?
  start_at = 2.weeks.from_now.beginning_of_week(:monday).change(hour: 14)
  Booking.create!(
    box_id: space.id,
    renter_id: profesional.id,
    start_at: start_at,
    end_at: start_at + 2.hours,
    hours: 2,
    duration_minutes: 120,
    total_amount_cents: space.default_price_per_slot_cents * 2,
    status: :confirmed,
    booking_type: :slot_based
  )
end

Rails.logger.debug 'Seed complete!'
Rails.logger.debug 'Admin: admin@jzg.cl / password123'
Rails.logger.debug 'Profesional: profesional@jzg.cl / password123'
