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

ActiveRecord::Schema[7.1].define(version: 2026_10_11_000001) do
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
    t.string "gid"
    t.string "output_name"
    t.bigint "download_speed", default: 0
    t.integer "retries", default: 0, null: false
    t.string "kind", default: "movie", null: false
    t.integer "season"
    t.integer "episode"
    t.integer "episode_count"
    t.integer "title_id"
    t.index ["created_at"], name: "index_downloads_on_created_at"
    t.index ["gid"], name: "index_downloads_on_gid"
    t.index ["status"], name: "index_downloads_on_status"
    t.index ["title_id"], name: "index_downloads_on_title_id"
  end

  create_table "plans", force: :cascade do |t|
    t.integer "title_id", null: false
    t.integer "season_number"
    t.date "planned_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["planned_on"], name: "index_plans_on_planned_on"
    t.index ["title_id"], name: "index_plans_on_title_id"
  end

  create_table "title_seasons", force: :cascade do |t|
    t.integer "title_id", null: false
    t.integer "number", null: false
    t.string "status", default: "want", null: false
    t.date "watched_on"
    t.integer "episode_count"
    t.date "air_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["title_id", "number"], name: "index_title_seasons_on_title_id_and_number", unique: true
    t.index ["title_id"], name: "index_title_seasons_on_title_id"
  end

  create_table "titles", force: :cascade do |t|
    t.string "media_type", null: false
    t.integer "tmdb_id"
    t.string "name", null: false
    t.string "original_name"
    t.string "original_language"
    t.integer "year"
    t.date "release_date"
    t.string "poster_path"
    t.string "backdrop_path"
    t.text "overview"
    t.string "status", default: "want", null: false
    t.date "watched_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "runtime"
    t.string "genres"
    t.string "imdb_id"
    t.float "tmdb_rating"
    t.json "details", default: {}
    t.datetime "details_fetched_at"
    t.index ["media_type", "tmdb_id"], name: "index_titles_on_media_type_and_tmdb_id", unique: true, where: "tmdb_id IS NOT NULL"
    t.index ["status"], name: "index_titles_on_status"
  end

  create_table "viewings", force: :cascade do |t|
    t.integer "title_id", null: false
    t.integer "season_number"
    t.date "watched_on", null: false
    t.integer "rating"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["title_id"], name: "index_viewings_on_title_id"
    t.index ["watched_on"], name: "index_viewings_on_watched_on"
  end

  add_foreign_key "downloads", "titles", on_delete: :nullify
  add_foreign_key "plans", "titles"
  add_foreign_key "title_seasons", "titles"
  add_foreign_key "viewings", "titles"
end
