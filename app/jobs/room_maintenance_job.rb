class RoomMaintenanceJob < ApplicationJob
  queue_as :default

  def perform(now: Time.current)
    expired_rooms = Room.expire_due!(now: now)
    expired_queue_entries = MatchQueueEntry.expire_due!(now: now)
    expired_match_pairs = MatchPair.expire_due!(now: now)
    trimmed_messages = trim_retained_messages(now: now)
    purged_rooms = Room.purge_closed_before!(Room.closed_purge_cutoff(now: now))

    expired_rooms.each do |room|
      RoomChannel.broadcast_to(room, type: "room.updated", room: room_broadcast_payload(room, now: now))
    end

    Rails.logger.info(
      "[hushpair.maintenance] expired_rooms=#{expired_rooms.size} expired_queue_entries=#{expired_queue_entries} expired_match_pairs=#{expired_match_pairs} trimmed_messages=#{trimmed_messages} purged_rooms=#{purged_rooms}"
    )
  end

  private

  def trim_retained_messages(now:)
    Room.find_each.sum do |room|
      room.enforce_message_retention!(now: now)
    end
  end

  def room_broadcast_payload(room, now:)
    {
      status: room.status,
      expires_at: room.expires_at&.iso8601,
      expiry_summary: room.expiry_summary(now: now)
    }
  end
end
