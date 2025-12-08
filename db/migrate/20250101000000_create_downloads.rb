class CreateDownloads < ActiveRecord::Migration[7.1]
  def change
    create_table :downloads do |t|
      t.string :url, null: false
      t.string :filename
      t.string :destination_path, null: false
      t.string :status, default: 'pending'
      t.float :progress, default: 0.0
      t.text :error_message
      t.bigint :file_size

      t.timestamps
    end

    add_index :downloads, :status
    add_index :downloads, :created_at
  end
end
