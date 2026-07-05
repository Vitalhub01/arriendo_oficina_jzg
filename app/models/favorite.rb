# frozen_string_literal: true

class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :space, class_name: 'Space', foreign_key: :box_id, optional: true
  alias box space
end
