# frozen_string_literal: true

class Office < ApplicationRecord
  has_many :spaces, class_name: 'Space', foreign_key: :office_id, dependent: :nullify, inverse_of: :office
  has_many :jornada_definitions, dependent: :destroy
  has_many_attached :photos

  validates :name, :address, :commune, :city, presence: true

  def full_address
    [address, commune, city].compact.join(', ')
  end
end
