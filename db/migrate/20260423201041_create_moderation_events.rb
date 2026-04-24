class CreateModerationEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :moderation_events do |t|
      t.references :room, null: false, foreign_key: true
      t.references :room_participant, null: false, foreign_key: true
      t.references :anonymous_session, null: false, foreign_key: true
      t.integer :kind, null: false
      t.string :reason
      t.jsonb :details, null: false, default: {}

      t.timestamps
    end

    add_index :moderation_events, :kind
  end
end
