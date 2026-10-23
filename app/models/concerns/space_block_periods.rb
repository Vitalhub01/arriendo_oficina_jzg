# frozen_string_literal: true

module SpaceBlockPeriods
  MORNING = {
    name: 'Mañana',
    start: '08:00',
    end: '14:00',
    position: 0
  }.freeze

  AFTERNOON = {
    name: 'Tarde',
    start: '14:00',
    end: '20:00',
    position: 1
  }.freeze

  PERIODS = [MORNING, AFTERNOON].freeze

  def self.time_on(hour_minute)
    Time.zone.parse("2000-01-01 #{hour_minute}")
  end
end
