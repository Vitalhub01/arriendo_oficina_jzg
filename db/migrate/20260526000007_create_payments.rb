# frozen_string_literal: true

class CreatePayments < ActiveRecord::Migration[7.0]
  def change
    create_table :payments do |t|
      t.references :booking, null: false, foreign_key: true
      t.references :payer, null: false, foreign_key: { to_table: :users }
      t.string :mercadopago_preference_id
      t.string :mercadopago_payment_id
      t.integer :status, null: false, default: 0
      t.integer :amount_cents, null: false, default: 0
      t.jsonb :raw_webhook, default: {}

      t.timestamps
    end

    add_index :payments, :mercadopago_preference_id
    add_index :payments, :mercadopago_payment_id
  end
end
