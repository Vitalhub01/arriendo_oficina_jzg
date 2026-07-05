# frozen_string_literal: true

class Faq < ApplicationRecord
  validates :question, :answer, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:position, :created_at) }
end
