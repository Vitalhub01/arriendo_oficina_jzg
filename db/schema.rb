# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_07_05_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "availability_blocks", force: :cascade do |t|
    t.bigint "box_id", null: false
    t.datetime "start_at", null: false
    t.datetime "end_at", null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["box_id", "start_at", "end_at"], name: "index_availability_blocks_on_box_id_and_start_at_and_end_at"
    t.index ["box_id"], name: "index_availability_blocks_on_box_id"
  end

  create_table "availability_rules", force: :cascade do |t|
    t.bigint "box_id", null: false
    t.integer "day_of_week", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.date "valid_from"
    t.date "valid_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["box_id", "day_of_week"], name: "index_availability_rules_on_box_id_and_day_of_week"
    t.index ["box_id"], name: "index_availability_rules_on_box_id"
  end

  create_table "booking_series", force: :cascade do |t|
    t.bigint "box_id", null: false
    t.bigint "renter_id", null: false
    t.integer "day_of_week", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["box_id", "status"], name: "index_booking_series_on_box_id_and_status"
    t.index ["box_id"], name: "index_booking_series_on_box_id"
    t.index ["renter_id"], name: "index_booking_series_on_renter_id"
  end

  create_table "bookings", force: :cascade do |t|
    t.bigint "box_id", null: false
    t.bigint "renter_id", null: false
    t.bigint "booking_series_id"
    t.datetime "start_at", null: false
    t.datetime "end_at", null: false
    t.integer "hours", null: false
    t.integer "status", default: 0, null: false
    t.integer "total_amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "payment_expires_at"
    t.integer "booking_type", default: 0, null: false
    t.bigint "jornada_definition_id"
    t.bigint "reschedule_credit_id"
    t.integer "discount_cents", default: 0, null: false
    t.jsonb "pricing_breakdown", default: {}, null: false
    t.index ["booking_series_id"], name: "index_bookings_on_booking_series_id"
    t.index ["box_id", "start_at", "end_at"], name: "index_bookings_on_box_id_and_start_at_and_end_at"
    t.index ["box_id"], name: "index_bookings_on_box_id"
    t.index ["jornada_definition_id"], name: "index_bookings_on_jornada_definition_id"
    t.index ["renter_id", "status"], name: "index_bookings_on_renter_id_and_status"
    t.index ["renter_id"], name: "index_bookings_on_renter_id"
    t.index ["reschedule_credit_id"], name: "index_bookings_on_reschedule_credit_id"
    t.index ["status", "payment_expires_at"], name: "index_bookings_on_status_and_payment_expires_at"
    t.exclusion_constraint "box_id WITH =, tsrange(start_at, end_at, '[)'::text) WITH &&", where: "status = ANY (ARRAY[0, 1])", using: :gist, name: "bookings_no_overlap"
  end

  create_table "boxes", force: :cascade do |t|
    t.bigint "owner_id"
    t.string "title", null: false
    t.text "description"
    t.string "address", null: false
    t.string "commune", null: false
    t.string "city", default: "Santiago", null: false
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.integer "box_type", default: 0, null: false
    t.integer "price_per_hour_cents", default: 0, null: false
    t.integer "minimum_hours", default: 1, null: false
    t.integer "status", default: 0, null: false
    t.jsonb "amenities", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "office_id"
    t.integer "capacity"
    t.string "dimensions"
    t.jsonb "equipment", default: [], null: false
    t.index ["box_type"], name: "index_boxes_on_box_type"
    t.index ["city"], name: "index_boxes_on_city"
    t.index ["commune"], name: "index_boxes_on_commune"
    t.index ["office_id"], name: "index_boxes_on_office_id"
    t.index ["owner_id"], name: "index_boxes_on_owner_id"
    t.index ["status"], name: "index_boxes_on_status"
  end

  create_table "faqs", force: :cascade do |t|
    t.string "question", null: false
    t.text "answer", null: false
    t.integer "position", default: 0, null: false
    t.boolean "visible", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "favorites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "box_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["box_id"], name: "index_favorites_on_box_id"
    t.index ["user_id", "box_id"], name: "index_favorites_on_user_id_and_box_id", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "payment_id", null: false
    t.bigint "user_id", null: false
    t.string "folio"
    t.string "provider", null: false
    t.string "provider_id"
    t.string "pdf_url"
    t.integer "status", default: 0, null: false
    t.jsonb "raw_response", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_id"], name: "index_invoices_on_payment_id", unique: true
    t.index ["user_id"], name: "index_invoices_on_user_id"
  end

  create_table "jornada_definitions", force: :cascade do |t|
    t.bigint "space_id"
    t.bigint "office_id"
    t.string "name", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.integer "price_cents", null: false
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["office_id"], name: "index_jornada_definitions_on_office_id"
    t.index ["space_id"], name: "index_jornada_definitions_on_space_id"
  end

  create_table "membership_plans", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.text "benefits"
    t.integer "price_cents", null: false
    t.integer "billing_period", default: 0, null: false
    t.integer "discount_percent", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "membership_plan_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "starts_at", null: false
    t.datetime "expires_at", null: false
    t.string "mercadopago_payment_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["membership_plan_id"], name: "index_memberships_on_membership_plan_id"
    t.index ["user_id", "status"], name: "index_memberships_on_user_id_and_status"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "offices", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "address", null: false
    t.string "commune", null: false
    t.string "city", default: "Santiago", null: false
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "payer_id", null: false
    t.string "mercadopago_preference_id"
    t.string "mercadopago_payment_id"
    t.integer "status", default: 0, null: false
    t.integer "amount_cents", default: 0, null: false
    t.jsonb "raw_webhook", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "payment_kind", default: 0, null: false
    t.bigint "membership_id"
    t.index ["booking_id"], name: "index_payments_on_booking_id", unique: true
    t.index ["membership_id"], name: "index_payments_on_membership_id"
    t.index ["mercadopago_payment_id"], name: "index_payments_on_mercadopago_payment_id"
    t.index ["mercadopago_preference_id"], name: "index_payments_on_mercadopago_preference_id"
    t.index ["payer_id"], name: "index_payments_on_payer_id"
  end

  create_table "pricing_rules", force: :cascade do |t|
    t.string "name", null: false
    t.integer "rule_type", null: false
    t.jsonb "config", default: {}, null: false
    t.boolean "active", default: true, null: false
    t.boolean "stackable", default: true, null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "professional_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "rut", null: false
    t.integer "validation_status", default: 0, null: false
    t.jsonb "superintendencia_data", default: {}
    t.text "rejection_reason"
    t.integer "age"
    t.string "gender"
    t.boolean "interested_in_networking"
    t.boolean "onboarding_completed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rut"], name: "index_professional_profiles_on_rut", unique: true
    t.index ["user_id"], name: "index_professional_profiles_on_user_id", unique: true
    t.index ["validation_status"], name: "index_professional_profiles_on_validation_status"
  end

  create_table "reschedule_credits", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "source_booking_id"
    t.bigint "applied_booking_id"
    t.integer "amount_cents", null: false
    t.integer "hours", null: false
    t.integer "status", default: 0, null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["applied_booking_id"], name: "index_reschedule_credits_on_applied_booking_id"
    t.index ["source_booking_id"], name: "index_reschedule_credits_on_source_booking_id"
    t.index ["user_id"], name: "index_reschedule_credits_on_user_id"
  end

  create_table "site_settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_site_settings_on_key", unique: true
  end

  create_table "testimonials", force: :cascade do |t|
    t.bigint "box_id", null: false
    t.bigint "profesional_id", null: false
    t.bigint "booking_id", null: false
    t.integer "rating"
    t.text "body"
    t.boolean "visible", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_testimonials_on_booking_id", unique: true
    t.index ["box_id"], name: "index_testimonials_on_box_id"
    t.index ["profesional_id"], name: "index_testimonials_on_profesional_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.integer "role", default: 2, null: false
    t.string "mercadopago_user_id"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "availability_blocks", "boxes"
  add_foreign_key "availability_rules", "boxes"
  add_foreign_key "booking_series", "boxes"
  add_foreign_key "booking_series", "users", column: "renter_id"
  add_foreign_key "bookings", "booking_series"
  add_foreign_key "bookings", "boxes"
  add_foreign_key "bookings", "jornada_definitions"
  add_foreign_key "bookings", "reschedule_credits"
  add_foreign_key "bookings", "users", column: "renter_id"
  add_foreign_key "boxes", "offices"
  add_foreign_key "boxes", "users", column: "owner_id"
  add_foreign_key "favorites", "boxes"
  add_foreign_key "favorites", "users"
  add_foreign_key "invoices", "payments"
  add_foreign_key "invoices", "users"
  add_foreign_key "jornada_definitions", "boxes", column: "space_id"
  add_foreign_key "jornada_definitions", "offices"
  add_foreign_key "memberships", "membership_plans"
  add_foreign_key "memberships", "users"
  add_foreign_key "payments", "bookings"
  add_foreign_key "payments", "memberships"
  add_foreign_key "payments", "users", column: "payer_id"
  add_foreign_key "professional_profiles", "users"
  add_foreign_key "reschedule_credits", "bookings", column: "applied_booking_id"
  add_foreign_key "reschedule_credits", "bookings", column: "source_booking_id"
  add_foreign_key "reschedule_credits", "users"
  add_foreign_key "testimonials", "bookings"
  add_foreign_key "testimonials", "boxes"
  add_foreign_key "testimonials", "users", column: "profesional_id"
end
