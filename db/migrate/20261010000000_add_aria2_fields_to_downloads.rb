class AddAria2FieldsToDownloads < ActiveRecord::Migration[7.1]
  def change
    add_column :downloads, :gid, :string
    add_column :downloads, :output_name, :string
    add_column :downloads, :download_speed, :bigint, default: 0
    add_index :downloads, :gid
  end
end
