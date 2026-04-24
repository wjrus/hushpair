class CreateRoomInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :room_invitations do |t|
      t.references :room, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :used_at
      t.integer :usage_limit, null: false, default: 1

      t.timestamps
    end

    add_index :room_invitations, :token_digest, unique: true
  end
end
