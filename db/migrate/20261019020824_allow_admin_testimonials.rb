# frozen_string_literal: true

class AllowAdminTestimonials < ActiveRecord::Migration[8.0]
  def change
    change_column_null :testimonials, :booking_id, true
    change_column_null :testimonials, :box_id, true
    change_column_null :testimonials, :profesional_id, true
    add_column :testimonials, :author_name, :string
  end
end
