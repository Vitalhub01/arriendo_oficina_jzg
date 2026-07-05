# frozen_string_literal: true

class MaintainBookingSeriesJob < ApplicationJob
  queue_as :default

  def perform
    BookingSeries.active.find_each do |series|
      GenerateSeriesBookingsJob.perform_now(series.id)
    end
  end
end
