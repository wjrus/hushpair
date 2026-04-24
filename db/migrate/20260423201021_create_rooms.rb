class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.uuid :public_id, null: false, default: "gen_random_uuid()"
      t.integer :mode, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :expires_at, null: false
      t.datetime :ended_at
      t.string :end_reason
      t.datetime :last_message_at
      t.integer :max_participants, null: false, default: 2

      t.timestamps
    end

    add_index :rooms, :public_id, unique: true
    add_index :rooms, [ :status, :expires_at ]
  end
end
