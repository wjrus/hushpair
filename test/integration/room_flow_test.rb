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

  test "api create join message and end chat flow works" do
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
end
