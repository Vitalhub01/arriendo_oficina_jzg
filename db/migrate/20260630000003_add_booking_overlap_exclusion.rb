# frozen_string_literal: true

class AddBookingOverlapExclusion < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL.squish
      ALTER TABLE bookings
      ADD CONSTRAINT bookings_no_overlap
      EXCLUDE USING gist (
        box_id WITH =,
        tsrange(start_at, end_at, '[)') WITH &&
      )
      WHERE (status IN (0, 1))
    SQL
  end

  def down
    execute 'ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_no_overlap'
  end
end
