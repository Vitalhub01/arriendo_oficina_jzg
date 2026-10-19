# frozen_string_literal: true

class Space < ApplicationRecord
  self.table_name = 'boxes'

  belongs_to :office, optional: true

  has_many :availability_rules, foreign_key: :box_id, dependent: :destroy, inverse_of: :space
  has_many :availability_blocks, foreign_key: :box_id, dependent: :destroy, inverse_of: :space
  has_many :bookings, foreign_key: :box_id, dependent: :destroy, inverse_of: :space
  has_many :booking_series, foreign_key: :box_id, dependent: :destroy, inverse_of: :space
  has_many :testimonials, foreign_key: :box_id, dependent: :destroy, inverse_of: :space
  has_many :jornada_definitions, dependent: :destroy, inverse_of: :space
  has_many :slot_rates, dependent: :destroy, inverse_of: :space
  has_many :schedule_blocks, dependent: :destroy, inverse_of: :space
  has_many :schedule_block_overrides, dependent: :destroy, inverse_of: :space
  has_many :pricing_rules, dependent: :destroy, inverse_of: :space
  has_many_attached :photos
  has_one_attached :terms_and_conditions

  enum :box_type, { clinical: 0, office: 1, workspace: 2 }
  enum :status, { draft: 0, published: 1, suspended: 2 }

  BOX_TYPE_LABELS = {
    'clinical' => 'Box clínico',
    'office' => 'Oficina',
    'workspace' => 'Workspace'
  }.freeze

  AMENITY_OPTIONS = %w[wifi bathroom parking air_conditioning waiting_room wheelchair_access].freeze

  validates :title, :city, presence: true
  validates :address, :commune, presence: true, unless: :inherits_location_from_office?

  before_validation :inherit_location_from_office
  before_validation :geocode_from_address, if: :needs_geocoding?
  validates :price_per_hour_cents, numericality: { greater_than: 0 }
  validates :minimum_hours, numericality: { greater_than: 0, only_integer: true }
  validates :slot_duration_minutes, numericality: { greater_than: 0, only_integer: true }
  validates :minimum_slots, numericality: { greater_than: 0, only_integer: true }
  validates :reschedule_notice_hours,
            numericality: { greater_than: 0, only_integer: true, allow_nil: true }
  validate :slot_duration_multiple_of_thirty
  validate :photos_required_for_publish, if: :published?
  validate :coordinates_required_for_publish, if: :published?
  validate :terms_and_conditions_must_be_pdf

  scope :published_spaces, -> { where(status: :published) }
  scope :published_boxes, -> { published_spaces }
  scope :by_city, ->(city) { where('LOWER(city) = ?', city.to_s.downcase) if city.present? }
  scope :by_commune, ->(commune) { where('LOWER(commune) = ?', commune.to_s.downcase) if commune.present? }
  scope :by_type, ->(type) { where(box_type: type) if type.present? && box_types.key?(type) }
  scope :by_min_price, ->(cents) { where(price_per_hour_cents: cents.to_i..) if cents.present? }
  scope :by_max_price, ->(cents) { where(price_per_hour_cents: ..cents.to_i) if cents.present? }

  def self.available_on(date:, hours:, start_time: '09:00')
    return published_spaces if date.blank? || hours.blank?

    parsed_date = Date.parse(date.to_s)
    hour, min = start_time.to_s.split(':').map(&:to_i)
    start_at = Time.zone.local(parsed_date.year, parsed_date.month, parsed_date.day, hour, min)
    end_at = start_at + hours.to_i.hours

    published_spaces.select do |space|
      AvailabilityChecker.new(space).available?(start_at, end_at)
    end
  end

  def box_type_label
    BOX_TYPE_LABELS[box_type]
  end

  def price_for_duration(hours)
    hours * price_per_hour_cents
  end

  def default_price_per_slot_cents
    (price_per_hour_cents * (slot_duration_minutes / 60.0)).round
  end

  def price_per_slot_at(time)
    rate = slot_rates.ordered.find { |r| r.covers_time?(time) }
    rate&.price_per_slot_cents || default_price_per_slot_cents
  end

  def schedule_blocks_for_date(date)
    day = (date.wday + 6) % 7
    schedule_blocks.for_day(day).ordered.reject { |block| !block.active_on?(date) || block.blocked_on?(date) }
  end

  def bookable_schedule_blocks_on(date)
    parsed = date.to_date
    return [] if parsed < Date.current

    now = Time.current
    schedule_blocks_for_date(parsed).select do |block|
      block.starts_at_on(parsed) > now
    end
  end

  def schedule_slots_in_week?(week_start)
    week = week_start.to_date.beginning_of_week(:monday)
    now = Time.current

    (0..6).any? do |offset|
      date = week + offset.days
      next false if date < Date.current

      schedule_blocks_for_date(date).any? { |block| block.starts_at_on(date) > now }
    end
  end

  def preferred_schedule_week_start
    week = Date.current.beginning_of_week(:monday)
    return week if schedule_slots_in_week?(week)

    next_week = week + 1.week
    return next_week if schedule_slots_in_week?(next_week)

    week
  end

  def price_for_interval(start_at, end_at)
    blocks = ScheduleBlockResolver.blocks_for_exact_interval(self, start_at, end_at)
    date = start_at.to_date
    blocks.sum { |block| block.price_cents_on(date) }
  end

  def schedule_block_count_for_interval(start_at, end_at)
    ScheduleBlockResolver.blocks_for_exact_interval(self, start_at, end_at).size
  end

  def schedule_blocks_within_time_range(date, range_start_time, range_end_time)
    schedule_blocks_for_date(date).select do |block|
      block.start_time >= range_start_time && block.end_time <= range_end_time
    end
  end

  def schedule_interval_for_slot_rate(date, slot_rate)
    blocks = schedule_blocks_within_time_range(date, slot_rate.start_time, slot_rate.end_time)
    interval_from_contiguous_blocks(date, blocks)
  end

  def schedule_interval_for_jornada(date, jornada_definition)
    blocks = schedule_blocks_within_time_range(date, jornada_definition.start_time, jornada_definition.end_time)
    interval_from_contiguous_blocks(date, blocks)
  end

  def primary_jornada_definition
    jornada_definitions.active.order(:position, :id).first
  end

  def slot_duration
    slot_duration_minutes.minutes
  end

  def formatted_price_per_hour
    Money.new(price_per_hour_cents, 'CLP').format(no_cents_if_whole: true)
  end

  def full_address
    [effective_address, effective_commune, effective_city].compact.join(', ')
  end

  def effective_address
    address.presence || office&.address
  end

  def effective_commune
    commune.presence || office&.commune
  end

  def effective_city
    city.presence || office&.city || city
  end

  def inherits_location_from_office?
    office_id.present? && office.present?
  end

  def cover_photo
    photos.first
  end

  def interval_from_contiguous_blocks(date, blocks)
    return nil if blocks.empty?

    contiguous = blocks.each_cons(2).all? do |a, b|
      a.ends_at_on(date) == b.starts_at_on(date)
    end
    return nil unless contiguous

    {
      start_at: blocks.first.starts_at_on(date),
      end_at: blocks.last.ends_at_on(date)
    }
  end

  private

  def inherit_location_from_office
    return unless office

    self.address = office.address
    self.commune = office.commune
    self.city = office.city
    self.latitude = office.latitude if office.latitude.present?
    self.longitude = office.longitude if office.longitude.present?
  end

  def needs_geocoding?
    latitude.blank? || longitude.blank?
  end

  def geocode_from_address
    return if effective_address.blank?

    coords = GeocoderService.geocode(
      effective_address,
      city: effective_city,
      commune: effective_commune
    )
    return unless coords

    self.latitude = coords[:latitude]
    self.longitude = coords[:longitude]
  end

  def photos_required_for_publish
    errors.add(:photos, 'debe tener al menos una foto para publicar') unless photos.attached?
  end

  def coordinates_required_for_publish
    errors.add(:latitude, 'es requerida para publicar') if latitude.blank?
    errors.add(:longitude, 'es requerida para publicar') if longitude.blank?
  end

  def slot_duration_multiple_of_thirty
    return if slot_duration_minutes.blank?
    return if (slot_duration_minutes % 30).zero?

    errors.add(:slot_duration_minutes, 'debe ser múltiplo de 30')
  end

  def terms_and_conditions_must_be_pdf
    return unless terms_and_conditions.attached?

    return if terms_and_conditions.content_type == 'application/pdf'

    errors.add(:terms_and_conditions, 'debe ser un archivo PDF')
  end
end

Box = Space unless defined?(Box)
