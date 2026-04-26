class CreateMatchQueueEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :match_queue_entries do |t|
      t.references :anonymous_session, null: false, foreign_key: true
      t.references :matched_room, foreign_key: { to_table: :rooms }
      t.integer :status, null: false, default: 0
      t.datetime :queued_at, null: false
      t.datetime :matched_at
      t.datetime :cancelled_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :match_queue_entries, [ :anonymous_session_id ],
      unique: true,
      where: "status = 0",
      name: "index_match_queue_entries_on_anonymous_session_id_when_queued"
    add_index :match_queue_entries, [ :status, :expires_at ]
  end
end
