class AddTvFieldsToDownloads < ActiveRecord::Migration[7.1]
  def change
    # movie, episode or season (a whole season in one file)
    add_column :downloads, :kind, :string, default: "movie", null: false
    add_column :downloads, :season, :integer
    add_column :downloads, :episode, :integer
    # Optional, for a whole-season file: lets Jellyfin show it as episodes 1-N.
    add_column :downloads, :episode_count, :integer
  end
end
