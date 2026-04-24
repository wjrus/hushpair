class AddMessageRetentionToRooms < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :message_retention_mode, :integer, null: false, default: 0
    add_column :rooms, :message_retention_line_limit, :integer, null: false, default: 250
    add_column :rooms, :message_retention_hours, :integer, null: false, default: 24
  end
end
