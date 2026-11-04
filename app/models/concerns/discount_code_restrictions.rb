# frozen_string_literal: true

module DiscountCodeRestrictions
  extend ActiveSupport::Concern

  ALL_WEEKDAYS = SpotOfferRecurrence::ALL_WEEKDAYS

  included do
    attr_accessor :discount_starts_on, :discount_ends_on

    before_validation :normalize_restriction_fields
    before_validation :apply_discount_date_fields
    after_find :load_discount_date_fields
    validate :allowed_weekdays_valid
    validate :allowed_time_window_valid
    validate :allowed_spaces_exist
  end

  def weekday_restricted?
    normalized_allowed_weekdays.any?
  end

  def time_restricted?
    allowed_start_time.present? && allowed_end_time.present?
  end

  def space_restricted?
    normalized_allowed_space_ids.any?
  end

  def schedule_restricted?
    weekday_restricted? || time_restricted?
  end

  def normalized_allowed_weekdays
    Array(allowed_weekdays).map(&:to_i).uniq.sort.intersection(ALL_WEEKDAYS)
  end

  def normalized_allowed_space_ids
    Array(allowed_space_ids).map(&:to_i).uniq.sort
  end

  def applies_to_booking_space?(booking)
    return true unless space_restricted?

    normalized_allowed_space_ids.include?(booking.box_id.to_i)
  end

  def applies_to_booking_schedule?(booking)
    return true unless schedule_restricted?

    zone_start = booking.start_at.in_time_zone
    zone_end = booking.end_at.in_time_zone

    if weekday_restricted?
      day = SpotOffer.app_wday_from_date(zone_start.to_date)
      return false unless normalized_allowed_weekdays.include?(day)
    end

    return true unless time_restricted?

    window_start = clock_seconds(allowed_start_time)
    window_end = clock_seconds(allowed_end_time)
    booking_start = clock_seconds(zone_start)
    booking_end = clock_seconds(zone_end)

    booking_start >= window_start && booking_end <= window_end
  end

  def within_user_use_limit?(user_id)
    return true if max_uses_per_user.blank?

    redemptions_count_for_user(user_id) < max_uses_per_user
  end

  def redemptions_count_for_user(user_id)
    bookings
      .where(renter_id: user_id)
      .where.not(status: %i[cancelled rescheduled])
      .count
  end

  def confirmed_bookings_count
    bookings.confirmed.count
  end

  def display_schedule_restrictions(space_titles_by_id: nil)
    parts = []
    parts << weekday_restrictions_summary if weekday_restricted?
    parts << time_restrictions_summary if time_restricted?
    parts << space_restrictions_summary(space_titles_by_id: space_titles_by_id) if space_restricted?
    parts.presence&.join(' · ')
  end

  def weekday_restrictions_summary
    days = normalized_allowed_weekdays
    return nil if days.empty?

    names = days.map { |d| AvailabilityRule::DAY_NAMES[d] }
    return 'Lunes a jueves' if days == [0, 1, 2, 3]
    return 'Lunes a viernes' if days == SpotOfferRecurrence::WEEKDAY_WORKDAYS

    names.to_sentence(two_words_connector: ' y ', last_word_connector: ' y ')
  end

  def time_restrictions_summary
    return unless time_restricted?

    "#{format_clock(allowed_start_time)}–#{format_clock(allowed_end_time)}"
  end

  def space_restrictions_summary(space_titles_by_id: nil)
    ids = normalized_allowed_space_ids
    return nil if ids.empty?

    titles = if space_titles_by_id
               ids.filter_map { |id| space_titles_by_id[id] }
             else
               Space.where(id: ids).order(:title).pluck(:title)
             end
    return "Espacio ##{ids.first}" if titles.empty?

    titles.to_sentence(two_words_connector: ' y ', last_word_connector: ' y ')
  end

  private

  def load_discount_date_fields
    self.discount_starts_on = starts_at&.in_time_zone&.to_date
    self.discount_ends_on = ends_at&.in_time_zone&.to_date
  end

  def apply_discount_date_fields
    if discount_starts_on.present?
      date = discount_starts_on.is_a?(Date) ? discount_starts_on : Date.parse(discount_starts_on.to_s)
      self.starts_at = Time.zone.local(date.year, date.month, date.day).beginning_of_day
    end

    return if discount_ends_on.blank?

    date = discount_ends_on.is_a?(Date) ? discount_ends_on : Date.parse(discount_ends_on.to_s)
    self.ends_at = Time.zone.local(date.year, date.month, date.day).end_of_day
  end

  def normalize_restriction_fields
    self.allowed_weekdays = Array(allowed_weekdays).reject { |d| d.to_s.blank? }.map(&:to_i).uniq.sort.intersection(ALL_WEEKDAYS)
    self.allowed_space_ids = Array(allowed_space_ids).reject { |id| id.to_s.blank? }.map(&:to_i).uniq.sort

    if allowed_start_time.blank? || allowed_end_time.blank?
      self.allowed_start_time = nil
      self.allowed_end_time = nil
    end
  end

  def allowed_weekdays_valid
    invalid = Array(allowed_weekdays).map(&:to_i) - ALL_WEEKDAYS
    return if invalid.empty?

    errors.add(:allowed_weekdays, 'incluye días no válidos')
  end

  def allowed_time_window_valid
    if allowed_start_time.blank? ^ allowed_end_time.blank?
      errors.add(:base, 'Indica hora de inicio y término de la franja, o deja ambas vacías')
      return
    end

    return unless time_restricted?

    errors.add(:allowed_end_time, 'debe ser posterior al inicio') if allowed_end_time <= allowed_start_time
  end

  def allowed_spaces_exist
    ids = normalized_allowed_space_ids
    return if ids.empty?

    missing = ids - Space.where(id: ids).pluck(:id)
    return if missing.empty?

    errors.add(:allowed_space_ids, "espacios inexistentes: #{missing.join(', ')}")
  end

  def format_clock(value)
    value.strftime('%H:%M')
  end

  def clock_seconds(time)
    (time.hour * 3600) + (time.min * 60) + time.sec
  end
end
