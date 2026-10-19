# frozen_string_literal: true

class AddProfessionToProfessionalProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :professional_profiles, :profession, :string
  end
end
