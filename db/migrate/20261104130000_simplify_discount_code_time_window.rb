# frozen_string_literal: true

class SimplifyDiscountCodeTimeWindow < ActiveRecord::Migration[8.0]
  class MigrationDiscountCode < ApplicationRecord
    self.table_name = 'discount_codes'
  end

  def up
    add_column :discount_codes, :allowed_start_time, :time
    add_column :discount_codes, :allowed_end_time, :time

    MigrationDiscountCode.reset_column_information
    MigrationDiscountCode.find_each do |code|
      windows = code.read_attribute(:allowed_time_windows)
      next unless windows.is_a?(Array)

      window = windows.first
      next unless window.is_a?(Hash)

      start_clock = window['start'] || window[:start]
      end_clock = window['end'] || window[:end]
      next if start_clock.blank? || end_clock.blank?

      code.update_columns(
        allowed_start_time: parse_clock(start_clock),
        allowed_end_time: parse_clock(end_clock)
      )
    end

    remove_column :discount_codes, :allowed_time_windows, :jsonb
  end

  def down
    add_column :discount_codes, :allowed_time_windows, :jsonb, default: [], null: false

    MigrationDiscountCode.reset_column_information
    MigrationDiscountCode.find_each do |code|
      next if code.allowed_start_time.blank? || code.allowed_end_time.blank?

      code.update_columns(
        allowed_time_windows: [
          {
            'start' => code.allowed_start_time.strftime('%H:%M'),
            'end' => code.allowed_end_time.strftime('%H:%M')
          }
        ]
      )
    end

    remove_column :discount_codes, :allowed_start_time, :time
    remove_column :discount_codes, :allowed_end_time, :time
  end

  private

  def parse_clock(value)
    Time.zone.parse(value.to_s.length <= 5 ? "#{value}:00" : value.to_s)
  end
end
