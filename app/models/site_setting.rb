# frozen_string_literal: true

class SiteSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.get(key, default = nil)
    find_by(key: key.to_s)&.value || default
  end

  def self.set(key, value)
    record = find_or_initialize_by(key: key.to_s)
    record.value = value
    record.save!
    record.value
  end
end
