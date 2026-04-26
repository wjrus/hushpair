require "test_helper"

class RoomFlowTest < ActionDispatch::IntegrationTest
  test "invite interstitial is shown before join" do
    post api_v1_rooms_path, params: { nickname: "Quiet Fox" }, as: :json

    payload = JSON.parse(response.body)
    room_slug = payload.dig("room", "slug")
    invite_token = payload.dig("invite", "token")

    guest = open_session
    guest.get room_path(room_slug, invite_token:)

    assert_equal 200, guest.response.status
    assert_match "You've been invited", guest.response.body
    assert_match "Join chat", guest.response.body
  end

  test "api create join message and terminal room exit flow works" do
    creator = open_session
    creator.post api_v1_rooms_path, params: { nickname: "Quiet Fox" }, as: :json
    assert_equal 201, creator.response.status

    created = JSON.parse(creator.response.body)
    room_public_id = created.dig("room", "id")
    room_slug = created.dig("room", "slug")
    invite_token = created.dig("invite", "token")
    creator_participant_token = creator.response.headers["X-Participant-Token"]

    guest = open_session
    guest.post "/api/v1/rooms/#{room_public_id}/join", params: { invite_token:, nickname: "Night Owl" }, as: :json
    assert_equal 201, guest.response.status
    guest_participant_token = guest.response.headers["X-Participant-Token"]

    creator.post api_v1_room_messages_path(room_public_id),
      params: { body: "hello there" },
      as: :json,
      headers: { "X-Participant-Token" => creator_participant_token }
    assert_equal 201, creator.response.status
    message_payload = JSON.parse(creator.response.body)
    assert_equal "hello there", message_payload.dig("message", "body")

    guest.post api_v1_room_end_chat_path(room_public_id),
      params: {},
      as: :json,
      headers: { "X-Participant-Token" => guest_participant_token }
    assert_equal 201, guest.response.status
    assert_equal "ended", JSON.parse(guest.response.body).dig("room", "status")

    creator.get api_v1_room_path(room_public_id), as: :json, headers: { "X-Participant-Token" => creator_participant_token }
    assert_equal "ended", JSON.parse(creator.response.body).dig("room", "status")

    creator.post leave_room_path(room_slug), params: { participant_token: creator_participant_token }
    assert_equal 302, creator.response.status
    assert_equal room_url(room_slug), creator.response.location
  end

  test "expired rooms do not restore participant access from return links" do
    creator = open_session
    creator.post api_v1_rooms_path, params: { nickname: "Quiet Fox" }, as: :json
    assert_equal 201, creator.response.status

    created = JSON.parse(creator.response.body)
    room_public_id = created.dig("room", "id")
    room_slug = created.dig("room", "slug")
    participant_token = creator.response.headers["X-Participant-Token"]

    room = Room.find_by!(public_id: room_public_id)
    room.update!(expires_at: 1.minute.ago)

    RoomMaintenanceJob.perform_now(now: Time.current)

    creator.get room_path(room_slug, participant_token: participant_token)

    assert_equal 200, creator.response.status
    assert_match "Room expired", creator.response.body
    assert_no_match "data-chat-room-public-id", creator.response.body
  end

  test "missing room slug shows a friendly unavailable page" do
    get room_path("cedar-muted-tide-willow")

    assert_equal 404, response.status
    assert_match "Chat not found", response.body
    assert_match "Start a new chat", response.body
  end

  test "ended matched room without participant access shows a friendly unavailable page" do
    room = Room.create!(
      expires_at: 1.minute.ago,
      last_message_at: 10.minutes.ago,
      max_participants: 2,
      mode: :random_match,
      status: :ended
    )

    get room_path(room)

    assert_equal 200, response.status
    assert_match "Chat ended", response.body
    assert_no_match "data-chat-room-public-id", response.body
  end

  test "bookmark links do not restore a participant in a different browser session" do
    creator = open_session
    creator.post api_v1_rooms_path, params: { nickname: "Quiet Fox" }, as: :json
    assert_equal 201, creator.response.status

    created = JSON.parse(creator.response.body)
    room_slug = created.dig("room", "slug")
    participant_token = creator.response.headers["X-Participant-Token"]

    stranger = open_session
    stranger.get room_path(room_slug, participant_token: participant_token)

    assert_equal 200, stranger.response.status
    assert_match "Bookmark limited to this browser", stranger.response.body
    assert_no_match "data-chat-room-public-id", stranger.response.body
  end

  test "home page shows open rooms for the current browser session" do
    creator = open_session
    creator.post rooms_path, params: { nickname: "Quiet Fox" }
    assert_equal 302, creator.response.status

    creator.get root_path

    assert_equal 200, creator.response.status
    assert_match "Your open rooms", creator.response.body
    assert_match "Open", creator.response.body
  end

  test "home page keeps queued match action in the match card action area" do
    seeker = open_session
    seeker.post match_path, params: { nickname: "Quiet Fox" }

    seeker.get root_path

    assert_equal 200, seeker.response.status
    assert_match "Resume search", seeker.response.body
    assert_match "home-entry-card__actions", seeker.response.body
  end

  test "matching flow pairs two browsers into a random room" do
    first = open_session
    first.post match_path, params: { nickname: "Quiet Fox" }
    assert_equal 302, first.response.status
    assert_equal match_url, first.response.location

    first.get match_path
    assert_equal 200, first.response.status
    assert_match "Looking for someone now", first.response.body
    assert_match "250 messages", first.response.body
    assert_no_match "people waiting", first.response.body
    assert_no_match "Set by hushpair", first.response.body

    second = open_session
    second.post match_path, params: { nickname: "Night Owl" }
    assert_equal 302, second.response.status

    matched_room = Room.order(:created_at).last
    assert_equal "random_match", matched_room.mode
    assert_equal "active", matched_room.status
    assert_equal 2, matched_room.room_participants.count

    first.get match_path
    assert_equal 302, first.response.status
    assert_equal room_url(matched_room), first.response.location

    first.get room_path(matched_room)
    assert_match "data-chat-participant-token", first.response.body
    assert_no_match "Bookmark", first.response.body
  end

  test "matching status endpoint returns matched room url for waiting browser" do
    first = open_session
    first.post match_path, params: { nickname: "Quiet Fox" }
    assert_equal 302, first.response.status

    second = open_session
    second.post match_path, params: { nickname: "Night Owl" }
    assert_equal 302, second.response.status

    matched_room = Room.order(:created_at).last

    first.get match_path(format: :json), as: :json
    assert_equal 200, first.response.status

    payload = JSON.parse(first.response.body)
    assert_equal "matched", payload.fetch("status")
    assert_equal room_path(matched_room), payload.fetch("room_url")
  end

  test "matching status endpoint does not expose public queue size" do
    first = open_session
    first.post match_path, params: { nickname: "Quiet Fox" }

    first.get match_path(format: :json), as: :json

    assert_equal 200, first.response.status
    payload = JSON.parse(first.response.body)
    assert_equal "queued", payload.fetch("status")
    assert_not payload.key?("queue_size")
  end

  test "repeated match requests keep one active queue entry for the browser" do
    seeker = open_session

    assert_difference -> { MatchQueueEntry.queued.count }, 1 do
      seeker.post match_path, params: { nickname: "Quiet Fox" }
      seeker.post match_path, params: { nickname: "Quiet Fox" }
    end

    assert_equal 1, MatchQueueEntry.queued.count
  end

  test "next from a matched chat avoids rematching the same pair too quickly" do
    first = open_session
    first.post match_path, params: { nickname: "Quiet Fox" }
    first_session = MatchQueueEntry.order(:created_at).last.anonymous_session

    second = open_session
    second.post match_path, params: { nickname: "Night Owl" }
    original_room = Room.order(:created_at).last
    second_session_id = original_room.room_participants.where.not(anonymous_session: first_session).pick(:anonymous_session_id)

    first.get match_path
    assert_equal room_url(original_room), first.response.location

    third = open_session
    third.post match_path, params: { nickname: "Pine Finch" }
    third_session = MatchQueueEntry.queued.order(:created_at).last.anonymous_session

    assert_difference -> { MatchPair.count }, 1 do
      first.post next_room_path(original_room)
    end

    new_room = Room.random_match.order(:created_at).last
    new_session_ids = new_room.room_participants.pluck(:anonymous_session_id)

    assert_equal 302, first.response.status
    assert_equal room_url(new_room), first.response.location
    assert_equal "ended", original_room.reload.status
    assert_includes new_session_ids, first_session.id
    assert_includes new_session_ids, third_session.id
    assert_not_includes new_session_ids, second_session_id

    second_queue_entry = MatchQueueEntry.current_for(AnonymousSession.find(second_session_id))
    assert_predicate second_queue_entry, :queued?

    second.get match_path(reason: "next")
    assert_match "back in line", second.response.body
  end

  test "matching flow can be cancelled" do
    seeker = open_session
    seeker.post match_path, params: { nickname: "Quiet Fox" }
    assert_equal 302, seeker.response.status

    assert_difference -> { MatchQueueEntry.cancelled.count }, 1 do
      seeker.delete match_path
    end

    assert_equal 302, seeker.response.status
    assert_equal root_url, seeker.response.location
  end

  test "report and leave creates a moderation event and redirects home" do
    creator = open_session
    creator.post api_v1_rooms_path, params: { nickname: "Quiet Fox" }, as: :json
    created = JSON.parse(creator.response.body)
    room_slug = created.dig("room", "slug")
    participant_token = creator.response.headers["X-Participant-Token"]

    assert_difference -> { ModerationEvent.report_submitted.count }, 1 do
      creator.post report_room_path(room_slug), params: { participant_token: participant_token, reason: "spam" }
    end

    assert_equal 302, creator.response.status
    assert_equal root_url, creator.response.location
    assert_equal "spam", ModerationEvent.report_submitted.last.reason
  end
end
