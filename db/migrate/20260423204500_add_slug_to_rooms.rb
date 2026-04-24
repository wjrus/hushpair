class AddSlugToRooms < ActiveRecord::Migration[8.1]
  class MigrationRoom < ApplicationRecord
    self.table_name = "rooms"
  end

  def up
    add_column :rooms, :slug, :string
    add_index :rooms, :slug, unique: true

    MigrationRoom.reset_column_information

    MigrationRoom.find_each do |room|
      room.update_columns(slug: next_slug)
    end

    change_column_null :rooms, :slug, false
  end

  def down
    remove_index :rooms, :slug
    remove_column :rooms, :slug
  end

  private

  def next_slug
    loop do
      slug = RoomSlugGenerator.generate
      return slug unless MigrationRoom.exists?(slug: slug)
    end
  end
end
