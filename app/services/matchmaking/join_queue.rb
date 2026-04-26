module Matchmaking
  class JoinQueue
    Result = Struct.new(:state, :room, :queue_entry, :participant_token, keyword_init: true) do
      def matched?
        state == :matched
      end

      def queued?
        state == :queued
      end
    end

    def self.call(session:, nickname: nil, now: Time.current)
      new(session:, nickname:, now:).call
    end

    def initialize(session:, nickname:, now:)
      @session = session
      @nickname = nickname
      @now = now
    end

    def call
      MatchQueueEntry.expire_due!(now: @now)
      MatchPair.expire_due!(now: @now)

      ActiveRecord::Base.transaction do
        @session.lock!
        current_entry = MatchQueueEntry.lock.where(id: MatchQueueEntry.current_for(@session)&.id).first
        return matched_result_for(current_entry) if current_entry&.matched? && current_entry.matched_room&.accessible?

        opponent = next_opponent
        return queue_result_for(current_entry) unless opponent

        match_with(opponent:, current_entry:)
      end
    end

    private

    def next_opponent
      MatchQueueEntry
        .queued_ready(@now)
        .where.not(anonymous_session_id: @session.id)
        .includes(:anonymous_session)
        .lock("FOR UPDATE SKIP LOCKED")
        .detect { |entry| !recently_matched?(entry.anonymous_session) }
    end

    def queue_result_for(current_entry)
      queue_entry = current_entry || @session.match_queue_entries.build(queued_at: @now)
      queue_entry.update!(
        status: :queued,
        matched_room: nil,
        matched_at: nil,
        cancelled_at: nil,
        queued_at: queue_entry.queued_at || @now,
        expires_at: MatchQueueEntry.queue_expiration_from(@now)
      )

      Result.new(state: :queued, queue_entry:)
    end

    def match_with(opponent:, current_entry:)
      room = build_room!
      participant_token = add_participant!(room:, session: @session, role: :creator, nickname: @nickname)
      add_participant!(room:, session: opponent.anonymous_session, role: :guest, nickname: opponent.anonymous_session.current_nickname)

      update_entry!(opponent, room)
      update_entry!(current_entry || @session.match_queue_entries.build(queued_at: @now), room)
      MatchPair.record!(room:, first_session: @session, second_session: opponent.anonymous_session, now: @now)

      Result.new(state: :matched, room:, participant_token:, queue_entry: current_entry)
    end

    def build_room!
      Room.create!(
        expires_at: Room.active_expiration_from(@now),
        last_message_at: @now,
        max_participants: 2,
        mode: :random_match,
        status: :active,
        **Room.match_retention_attributes
      )
    end

    def add_participant!(room:, session:, role:, nickname:)
      raw_token = TokenDigest.generate

      room.room_participants.create!(
        anonymous_session: session,
        joined_at: @now,
        last_seen_at: @now,
        nickname: nickname.presence,
        nickname_state: nickname.present? ? :accepted : :pending_review,
        participant_token_digest: TokenDigest.hexdigest(raw_token),
        role: role
      )

      raw_token
    end

    def update_entry!(entry, room)
      entry.update!(
        status: :matched,
        matched_room: room,
        matched_at: @now,
        cancelled_at: nil,
        expires_at: room.expires_at
      )
    end

    def matched_result_for(entry)
      Result.new(state: :matched, room: entry.matched_room, queue_entry: entry)
    end

    def recently_matched?(opponent_session)
      MatchPair.recent_between?(@session, opponent_session, now: @now)
    end
  end
end
