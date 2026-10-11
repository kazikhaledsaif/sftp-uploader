class CreateTitles < ActiveRecord::Migration[7.1]
  def change
    # A movie or TV show on the watchlist. Details come from TMDB when available.
    create_table :titles do |t|
      t.string :media_type, null: false             # movie or tv
      t.integer :tmdb_id
      t.string :name, null: false
      t.string :original_name                       # e.g. Hindi script
      t.string :original_language
      t.integer :year
      t.date :release_date                          # first air date for TV
      t.string :poster_path
      t.string :backdrop_path
      t.text :overview
      t.string :status, null: false, default: "want" # want, watching, watched, dropped
      t.date :watched_on
      t.timestamps
    end
    add_index :titles, %i[media_type tmdb_id], unique: true, where: "tmdb_id IS NOT NULL"
    add_index :titles, :status

    # TV is tracked per season (a whole season is watched at once).
    create_table :title_seasons do |t|
      t.references :title, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :status, null: false, default: "want" # want or watched
      t.date :watched_on
      t.integer :episode_count
      t.date :air_date
      t.timestamps
    end
    add_index :title_seasons, %i[title_id number], unique: true

    add_reference :downloads, :title, foreign_key: { on_delete: :nullify }
  end
end
