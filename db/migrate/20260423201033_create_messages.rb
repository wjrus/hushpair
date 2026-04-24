class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :room, null: false, foreign_key: true
      t.references :room_participant, null: false, foreign_key: true
      t.integer :sequence_number, null: false
      t.text :body, null: false
      t.string :client_message_uuid, null: false
      t.boolean :flagged, null: false, default: false
      t.jsonb :flag_reasons, null: false, default: []

      t.timestamps
    end

    add_index :messages, [ :room_id, :sequence_number ], unique: true
    add_index :messages, [ :room_id, :client_message_uuid ], unique: true
  end
end
