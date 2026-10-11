class CreateViewingsAndPlans < ActiveRecord::Migration[7.1]
  def change
    # The diary: one row per watch (a movie, or one whole TV season).
    create_table :viewings do |t|
      t.references :title, null: false, foreign_key: true
      t.integer :season_number                # nil for movies
      t.date :watched_on, null: false
      t.integer :rating                       # half stars: 1..10 = 0.5..5 stars
      t.text :note
      t.timestamps
    end
    add_index :viewings, :watched_on

    # "I'll watch this on Saturday."
    create_table :plans do |t|
      t.references :title, null: false, foreign_key: true
      t.integer :season_number
      t.date :planned_on, null: false
      t.timestamps
    end
    add_index :plans, :planned_on

    # Details for sorting/filtering; the rest (cast, trailer, scores...) in details.
    add_column :titles, :runtime, :integer          # minutes (per episode for TV)
    add_column :titles, :genres, :string             # "Drama, Comedy"
    add_column :titles, :imdb_id, :string
    add_column :titles, :tmdb_rating, :float
    add_column :titles, :details, :json, default: {}
    add_column :titles, :details_fetched_at, :datetime
  end
end
