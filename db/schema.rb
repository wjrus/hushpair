# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_25_170000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "anonymous_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "current_nickname"
    t.string "ip_hash"
    t.datetime "last_seen_at"
    t.uuid "public_id", default: -> { "gen_random_uuid()" }, null: false
    t.string "session_token_digest", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "user_agent_hash"
    t.index ["public_id"], name: "index_anonymous_sessions_on_public_id", unique: true
    t.index ["session_token_digest"], name: "index_anonymous_sessions_on_session_token_digest", unique: true
  end

  create_table "match_pairs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "matched_at", null: false
    t.string "pair_digest", null: false
    t.bigint "room_id", null: false
    t.datetime "updated_at", null: false
    t.index ["matched_at"], name: "index_match_pairs_on_matched_at"
    t.index ["pair_digest", "expires_at"], name: "index_match_pairs_on_pair_digest_and_expires_at"
    t.index ["room_id"], name: "index_match_pairs_on_room_id"
  end

  create_table "match_queue_entries", force: :cascade do |t|
    t.bigint "anonymous_session_id", null: false
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "matched_at"
    t.bigint "matched_room_id"
    t.datetime "queued_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["anonymous_session_id"], name: "index_match_queue_entries_on_anonymous_session_id"
    t.index ["anonymous_session_id"], name: "index_match_queue_entries_on_anonymous_session_id_when_queued", unique: true, where: "(status = 0)"
    t.index ["matched_room_id"], name: "index_match_queue_entries_on_matched_room_id"
    t.index ["status", "expires_at"], name: "index_match_queue_entries_on_status_and_expires_at"
  end

  create_table "messages", force: :cascade do |t|
    t.text "body", null: false
    t.string "client_message_uuid", null: false
    t.datetime "created_at", null: false
    t.jsonb "flag_reasons", default: [], null: false
    t.boolean "flagged", default: false, null: false
    t.bigint "room_id", null: false
    t.bigint "room_participant_id", null: false
    t.integer "sequence_number", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id", "client_message_uuid"], name: "index_messages_on_room_id_and_client_message_uuid", unique: true
    t.index ["room_id", "sequence_number"], name: "index_messages_on_room_id_and_sequence_number", unique: true
    t.index ["room_id"], name: "index_messages_on_room_id"
    t.index ["room_participant_id"], name: "index_messages_on_room_participant_id"
  end

  create_table "moderation_events", force: :cascade do |t|
    t.bigint "anonymous_session_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}, null: false
    t.integer "kind", null: false
    t.string "reason"
    t.bigint "room_id", null: false
    t.bigint "room_participant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["anonymous_session_id"], name: "index_moderation_events_on_anonymous_session_id"
    t.index ["kind"], name: "index_moderation_events_on_kind"
    t.index ["room_id"], name: "index_moderation_events_on_room_id"
    t.index ["room_participant_id"], name: "index_moderation_events_on_room_participant_id"
  end

  create_table "room_invitations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.bigint "room_id", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.integer "usage_limit", default: 1, null: false
    t.datetime "used_at"
    t.index ["room_id"], name: "index_room_invitations_on_room_id"
    t.index ["token_digest"], name: "index_room_invitations_on_token_digest", unique: true
  end

  create_table "room_participants", force: :cascade do |t|
    t.bigint "anonymous_session_id", null: false
    t.datetime "blocked_at"
    t.datetime "created_at", null: false
    t.datetime "joined_at", null: false
    t.datetime "last_seen_at"
    t.datetime "left_at"
    t.text "nickname"
    t.integer "nickname_state", default: 0, null: false
    t.string "participant_token_digest", null: false
    t.integer "role", null: false
    t.bigint "room_id", null: false
    t.datetime "updated_at", null: false
    t.index ["anonymous_session_id"], name: "index_room_participants_on_anonymous_session_id"
    t.index ["participant_token_digest"], name: "index_room_participants_on_participant_token_digest", unique: true
    t.index ["room_id", "anonymous_session_id"], name: "index_room_participants_on_room_id_and_anonymous_session_id", unique: true
    t.index ["room_id"], name: "index_room_participants_on_room_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "end_reason"
    t.datetime "ended_at"
    t.datetime "expires_at", null: false
    t.datetime "last_message_at"
    t.integer "max_participants", default: 2, null: false
    t.integer "message_retention_hours", default: 24, null: false
    t.integer "message_retention_line_limit", default: 250, null: false
    t.integer "message_retention_mode", default: 0, null: false
    t.integer "mode", default: 0, null: false
    t.uuid "public_id", default: -> { "gen_random_uuid()" }, null: false
    t.string "slug", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_rooms_on_public_id", unique: true
    t.index ["slug"], name: "index_rooms_on_slug", unique: true
    t.index ["status", "expires_at"], name: "index_rooms_on_status_and_expires_at"
  end

  add_foreign_key "match_pairs", "rooms"
  add_foreign_key "match_queue_entries", "anonymous_sessions"
  add_foreign_key "match_queue_entries", "rooms", column: "matched_room_id"
  add_foreign_key "messages", "room_participants"
  add_foreign_key "messages", "rooms"
  add_foreign_key "moderation_events", "anonymous_sessions"
  add_foreign_key "moderation_events", "room_participants"
  add_foreign_key "moderation_events", "rooms"
  add_foreign_key "room_invitations", "rooms"
  add_foreign_key "room_participants", "anonymous_sessions"
  add_foreign_key "room_participants", "rooms"
end
