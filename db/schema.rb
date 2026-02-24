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

ActiveRecord::Schema[8.0].define(version: 2026_02_24_110207) do
  create_table "audit_results", force: :cascade do |t|
    t.integer "business_id", null: false
    t.boolean "has_website", default: false, null: false
    t.boolean "has_ssl", default: false, null: false
    t.boolean "is_mobile_friendly", default: false, null: false
    t.string "cms_detected"
    t.integer "load_time_ms"
    t.integer "copyright_year"
    t.integer "score", default: 0, null: false
    t.text "issues"
    t.datetime "audited_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audited_at"], name: "index_audit_results_on_audited_at"
    t.index ["business_id"], name: "index_audit_results_on_business_id"
    t.index ["has_website"], name: "index_audit_results_on_has_website"
    t.index ["score"], name: "index_audit_results_on_score"
  end

  create_table "businesses", force: :cascade do |t|
    t.string "name", null: false
    t.string "category"
    t.string "phone"
    t.string "email"
    t.string "address"
    t.string "city"
    t.string "province"
    t.string "website_url"
    t.string "source", default: "manual", null: false
    t.boolean "needs_audit", default: true, null: false
    t.datetime "scraped_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city"], name: "index_businesses_on_city"
    t.index ["name", "city"], name: "index_businesses_on_name_and_city", unique: true
    t.index ["needs_audit"], name: "index_businesses_on_needs_audit"
    t.index ["province"], name: "index_businesses_on_province"
    t.index ["source"], name: "index_businesses_on_source"
  end

  create_table "scrape_jobs", force: :cascade do |t|
    t.string "source", null: false
    t.string "category"
    t.string "location"
    t.string "status", default: "pending", null: false
    t.integer "results_count", default: 0, null: false
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_scrape_jobs_on_created_at"
    t.index ["source"], name: "index_scrape_jobs_on_source"
    t.index ["status"], name: "index_scrape_jobs_on_status"
  end

  create_table "settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  add_foreign_key "audit_results", "businesses"
end
