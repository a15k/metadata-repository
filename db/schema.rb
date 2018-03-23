# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180322165555) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "citext"

  create_table "application_users", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.bigint "application_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["application_id"], name: "index_application_users_on_application_id"
    t.index ["uuid", "application_id"], name: "index_application_users_on_uuid_and_application_id", unique: true
  end

  create_table "applications", force: :cascade do |t|
    t.uuid "uuid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uuid"], name: "index_applications_on_uuid", unique: true
  end

  create_table "formats", force: :cascade do |t|
    t.citext "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_formats_on_name", unique: true
  end

  create_table "languages", force: :cascade do |t|
    t.citext "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_languages_on_name", unique: true
  end

  create_table "metadata", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.bigint "application_user_id"
    t.bigint "resource_id", null: false
    t.bigint "format_id", null: false
    t.uuid "uuid", null: false
    t.jsonb "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "value jsonb_path_ops", name: "index_metadata_on_value_jsonb_path_ops", using: :gin
    t.index ["application_id"], name: "index_metadata_on_application_id"
    t.index ["application_user_id"], name: "index_metadata_on_application_user_id"
    t.index ["format_id"], name: "index_metadata_on_format_id"
    t.index ["resource_id"], name: "index_metadata_on_resource_id"
    t.index ["uuid", "application_id"], name: "index_metadata_on_uuid_and_application_id", unique: true
    t.index ["value"], name: "index_metadata_on_value", using: :gin
  end

  create_table "resources", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.bigint "application_user_id"
    t.bigint "format_id", null: false
    t.bigint "language_id"
    t.uuid "uuid", null: false
    t.string "uri", null: false
    t.citext "type", null: false
    t.text "content", null: false
    t.tsvector "tsvector", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["application_id"], name: "index_resources_on_application_id"
    t.index ["application_user_id"], name: "index_resources_on_application_user_id"
    t.index ["format_id"], name: "index_resources_on_format_id"
    t.index ["language_id"], name: "index_resources_on_language_id"
    t.index ["tsvector"], name: "index_resources_on_tsvector", using: :gin
    t.index ["uri", "application_id"], name: "index_resources_on_uri_and_application_id", unique: true
    t.index ["uuid", "application_id"], name: "index_resources_on_uuid_and_application_id", unique: true
  end

  create_table "stats", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.bigint "application_user_id"
    t.bigint "resource_id", null: false
    t.bigint "format_id", null: false
    t.uuid "uuid", null: false
    t.jsonb "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "value jsonb_path_ops", name: "index_stats_on_value_jsonb_path_ops", using: :gin
    t.index ["application_id"], name: "index_stats_on_application_id"
    t.index ["application_user_id"], name: "index_stats_on_application_user_id"
    t.index ["format_id"], name: "index_stats_on_format_id"
    t.index ["resource_id"], name: "index_stats_on_resource_id"
    t.index ["uuid", "application_id"], name: "index_stats_on_uuid_and_application_id", unique: true
    t.index ["value"], name: "index_stats_on_value", using: :gin
  end

  add_foreign_key "application_users", "applications", on_update: :cascade, on_delete: :cascade
  add_foreign_key "metadata", "application_users", on_update: :cascade, on_delete: :nullify
  add_foreign_key "metadata", "applications", on_update: :cascade, on_delete: :cascade
  add_foreign_key "metadata", "formats", on_update: :cascade, on_delete: :cascade
  add_foreign_key "metadata", "resources", on_update: :cascade, on_delete: :cascade
  add_foreign_key "resources", "application_users", on_update: :cascade, on_delete: :nullify
  add_foreign_key "resources", "applications", on_update: :cascade, on_delete: :cascade
  add_foreign_key "resources", "formats", on_update: :cascade, on_delete: :cascade
  add_foreign_key "resources", "languages", on_update: :cascade, on_delete: :nullify
  add_foreign_key "stats", "application_users", on_update: :cascade, on_delete: :nullify
  add_foreign_key "stats", "applications", on_update: :cascade, on_delete: :cascade
  add_foreign_key "stats", "formats", on_update: :cascade, on_delete: :cascade
  add_foreign_key "stats", "resources", on_update: :cascade, on_delete: :cascade
end
