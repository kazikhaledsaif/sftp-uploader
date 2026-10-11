class CreateSettings < ActiveRecord::Migration[7.1]
  def change
    # Small key/value store for app settings (e.g. the download speed mode).
    create_table :settings do |t|
      t.string :key, null: false
      t.text :value
      t.timestamps
    end
    add_index :settings, :key, unique: true
  end
end
