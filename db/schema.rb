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

ActiveRecord::Schema[7.1].define(version: 2025_01_01_000000) do
  create_table "downloads", force: :cascade do |t|
    t.string "url", null: false
    t.string "filename"
    t.string "destination_path", null: false
    t.string "status", default: "pending"
    t.float "progress", default: 0.0
    t.text "error_message"
    t.bigint "file_size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_downloads_on_created_at"
    t.index ["status"], name: "index_downloads_on_status"
  end

end
