# frozen_string_literal: true

class CreateSiteBrandings < ActiveRecord::Migration[8.0]
  def change
    create_table :site_brandings do |t|
      t.timestamps
    end
  end
end
