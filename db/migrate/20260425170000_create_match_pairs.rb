class CreateMatchPairs < ActiveRecord::Migration[8.1]
  def change
    create_table :match_pairs do |t|
      t.references :room, null: false, foreign_key: true
      t.string :pair_digest, null: false
      t.datetime :matched_at, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :match_pairs, [ :pair_digest, :expires_at ]
    add_index :match_pairs, :matched_at
  end
end
