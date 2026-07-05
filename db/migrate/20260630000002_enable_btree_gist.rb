# frozen_string_literal: true

class EnableBtreeGist < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'btree_gist'
  end
end
