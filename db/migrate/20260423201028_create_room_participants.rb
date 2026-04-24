class CreateRoomParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :room_participants do |t|
      t.references :room, null: false, foreign_key: true
      t.references :anonymous_session, null: false, foreign_key: true
      t.integer :role, null: false
      t.string :nickname
      t.integer :nickname_state, null: false, default: 0
      t.datetime :joined_at, null: false
      t.datetime :left_at
      t.datetime :last_seen_at
      t.datetime :blocked_at
      t.string :participant_token_digest, null: false

      t.timestamps
    end

    add_index :room_participants, [ :room_id, :anonymous_session_id ], unique: true
    add_index :room_participants, :participant_token_digest, unique: true
  end
end
