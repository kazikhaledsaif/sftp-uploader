class AddRetriesToDownloads < ActiveRecord::Migration[7.1]
  def change
    # Automatic restarts after the server answered "too many requests" (HTTP 429/503).
    add_column :downloads, :retries, :integer, default: 0, null: false
  end
end
