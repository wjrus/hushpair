class RoomMaintenanceJob < ApplicationJob
  queue_as :default
  RANDOM_MATCH_INACTIVITY_TIMEOUT = 90.seconds

  def perform(now: Time.current)
    inactive_match_rooms = end_inactive_random_match_rooms(now: now)
    expired_rooms = Room.expire_due!(now: now)
    expired_queue_entries = MatchQueueEntry.expire_due!(now: now)
    expired_match_pairs = MatchPair.expire_due!(now: now)
    trimmed_messages = trim_retained_messages(now: now)
    purged_rooms = Room.purge_closed_before!(Room.closed_purge_cutoff(now: now))

    expired_rooms.each do |room|
      RoomChannel.broadcast_to(room, type: "room.updated", room: room_broadcast_payload(room, now: now))
    end

    Rails.logger.info(
      "[hushpair.maintenance] inactive_match_rooms=#{inactive_match_rooms.size} expired_rooms=#{expired_rooms.size} expired_queue_entries=#{expired_queue_entries} expired_match_pairs=#{expired_match_pairs} trimmed_messages=#{trimmed_messages} purged_rooms=#{purged_rooms}"
    )
  end

  private

  def end_inactive_random_match_rooms(now:)
    Room.random_match.active.includes(:room_participants).find_each.filter_map do |room|
      next unless room.room_participants.size == room.max_participants

      stale_participants = room.room_participants.select { |participant| participant.last_seen_at.blank? || participant.last_seen_at < now - RANDOM_MATCH_INACTIVITY_TIMEOUT }
      next if stale_participants.empty?

      active_participants = room.room_participants - stale_participants
      room.end_chat!(participant: stale_participants.first, reason: "ended_by_participant_inactive", at: now)

      active_participants.each do |participant|
        next if participant.last_seen_at.blank? || participant.last_seen_at < now - RANDOM_MATCH_INACTIVITY_TIMEOUT

        Matchmaking::JoinQueue.call(
          session: participant.anonymous_session,
          nickname: participant.nickname,
          now: now
        )
      end

      RoomChannel.broadcast_to(room, type: "room.updated", room: room_broadcast_payload(room, now: now))
      room
    end
  end

  def trim_retained_messages(now:)
    Room.find_each.sum do |room|
      room.enforce_message_retention!(now: now)
    end
  end

  def room_broadcast_payload(room, now:)
    {
      status: room.status,
      expires_at: room.expires_at&.iso8601,
      expiry_summary: room.expiry_summary(now: now),
      end_reason: room.end_reason,
      match_url: match_url_for(room),
      system_notice: MatchHandoff.system_notice(room)
    }
  end

  def match_url_for(room)
    return unless MatchHandoff.handoff?(room)

    Rails.application.routes.url_helpers.match_path(reason: "next")
  end
end
