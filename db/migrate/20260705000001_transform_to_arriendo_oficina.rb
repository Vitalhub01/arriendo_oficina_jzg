# frozen_string_literal: true

class TransformToArriendoOficina < ActiveRecord::Migration[8.0]
  def up
    create_table :offices do |t|
      t.string :name, null: false
      t.text :description
      t.string :address, null: false
      t.string :commune, null: false
      t.string :city, default: 'Santiago', null: false
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.timestamps
    end

    create_table :site_settings do |t|
      t.string :key, null: false
      t.text :value
      t.timestamps
      t.index :key, unique: true
    end

    create_table :faqs do |t|
      t.string :question, null: false
      t.text :answer, null: false
      t.integer :position, default: 0, null: false
      t.boolean :visible, default: true, null: false
      t.timestamps
    end

    create_table :professional_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :rut, null: false
      t.integer :validation_status, default: 0, null: false
      t.jsonb :superintendencia_data, default: {}
      t.text :rejection_reason
      t.integer :age
      t.string :gender
      t.boolean :interested_in_networking
      t.boolean :onboarding_completed, default: false, null: false
      t.timestamps
      t.index :rut, unique: true
      t.index :validation_status
    end

    add_reference :boxes, :office, foreign_key: true
    add_column :boxes, :capacity, :integer
    add_column :boxes, :dimensions, :string
    add_column :boxes, :equipment, :jsonb, default: [], null: false

    create_table :jornada_definitions do |t|
      t.references :space, foreign_key: { to_table: :boxes }
      t.references :office, foreign_key: true
      t.string :name, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.integer :price_cents, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    create_table :pricing_rules do |t|
      t.string :name, null: false
      t.integer :rule_type, null: false
      t.jsonb :config, default: {}, null: false
      t.boolean :active, default: true, null: false
      t.boolean :stackable, default: true, null: false
      t.integer :priority, default: 0, null: false
      t.timestamps
    end

    create_table :membership_plans do |t|
      t.string :name, null: false
      t.text :description
      t.text :benefits
      t.integer :price_cents, null: false
      t.integer :billing_period, default: 0, null: false
      t.integer :discount_percent, default: 0, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :membership_plan, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.datetime :starts_at, null: false
      t.datetime :expires_at, null: false
      t.string :mercadopago_payment_id
      t.timestamps
      t.index %i[user_id status]
    end

    create_table :reschedule_credits do |t|
      t.references :user, null: false, foreign_key: true
      t.references :source_booking, foreign_key: { to_table: :bookings }
      t.references :applied_booking, foreign_key: { to_table: :bookings }
      t.integer :amount_cents, null: false
      t.integer :hours, null: false
      t.integer :status, default: 0, null: false
      t.datetime :expires_at
      t.timestamps
    end

    add_column :bookings, :booking_type, :integer, default: 0, null: false
    add_reference :bookings, :jornada_definition, foreign_key: true
    add_reference :bookings, :reschedule_credit, foreign_key: true
    add_column :bookings, :discount_cents, :integer, default: 0, null: false
    add_column :bookings, :pricing_breakdown, :jsonb, default: {}, null: false

    add_column :payments, :payment_kind, :integer, default: 0, null: false
    add_reference :payments, :membership, foreign_key: true

    create_table :invoices do |t|
      t.references :payment, null: false, foreign_key: true, index: { unique: true }
      t.references :user, null: false, foreign_key: true
      t.string :folio
      t.string :provider, null: false
      t.string :provider_id
      t.string :pdf_url
      t.integer :status, default: 0, null: false
      t.jsonb :raw_response, default: {}
      t.timestamps
    end

    rename_column :reviews, :renter_id, :profesional_id
    rename_table :reviews, :testimonials
    change_column_null :testimonials, :rating, true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
