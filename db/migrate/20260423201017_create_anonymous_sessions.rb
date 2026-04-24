class CreateAnonymousSessions < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :anonymous_sessions do |t|
      t.uuid :public_id, null: false, default: "gen_random_uuid()"
      t.string :session_token_digest, null: false
      t.string :current_nickname, limit: 40
      t.integer :status, null: false, default: 0
      t.datetime :last_seen_at
      t.string :ip_hash
      t.string :user_agent_hash

      t.timestamps
    end

    add_index :anonymous_sessions, :public_id, unique: true
    add_index :anonymous_sessions, :session_token_digest, unique: true
  end
end
