class WidenEncryptedNicknameColumns < ActiveRecord::Migration[8.1]
  def change
    change_column :anonymous_sessions, :current_nickname, :text
    change_column :room_participants, :nickname, :text
  end
end
