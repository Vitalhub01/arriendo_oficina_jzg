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
  has_many_attached :photos

  enum :box_type, { clinical: 0, office: 1, workspace: 2 }
  enum :status, { draft: 0, published: 1, suspended: 2 }

  BOX_TYPE_LABELS = {
    'clinical' => 'Box clínico',
    'office' => 'Oficina',
    'workspace' => 'Workspace'
  }.freeze

  AMENITY_OPTIONS = %w[wifi bathroom parking air_conditioning waiting_room wheelchair_access].freeze

  validates :title, :address, :commune, :city, presence: true
  validates :price_per_hour_cents, numericality: { greater_than: 0 }
  validates :minimum_hours, numericality: { greater_than: 0, only_integer: true }
  validates :slot_duration_minutes, numericality: { greater_than: 0, only_integer: true }
  validates :minimum_slots, numericality: { greater_than: 0, only_integer: true }
  validate :slot_duration_multiple_of_thirty
  validate :photos_required_for_publish, if: :published?
  validate :coordinates_required_for_publish, if: :published?

  scope :published_spaces, -> { where(status: :published) }
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

  def slot_duration
    slot_duration_minutes.minutes
  end

  def formatted_price_per_hour
    Money.new(price_per_hour_cents, 'CLP').format(no_cents_if_whole: true)
  end

  def full_address
    [address, commune, city].compact.join(', ')
  end

  def cover_photo
    photos.first
  end

  private

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
end

Box = Space unless defined?(Box)
