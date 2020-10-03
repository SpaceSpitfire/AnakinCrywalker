class CreateServerTable < ActiveRecord::Migration[6.0]
  def self.up
    create_table :servers do |t|
      t.string :discord_id, null: false, unique: true
      t.boolean :crywalker, default: false, null: false
      t.boolean :sandstorm_mode, default: false, null: false
      t.boolean :penis_mode, default: false, null: false
      t.boolean :rename_mode, default: false, null: false
      t.string :nick
      t.timestamps
    end
  end
  def self.down
    drop_table :servers
  end
end
