module MatchHandoff
  END_REASONS = %w[
    ended_by_next_match
    ended_by_participant_inactive
  ].freeze

  SYSTEM_NOTICES = {
    "ended_by_next_match" => "Your chat partner moved on. Looking for someone new...",
    "ended_by_participant_inactive" => "Your chat partner disconnected. Looking for someone new..."
  }.freeze

  module_function

  def handoff?(room)
    room.random_match? && room.ended? && END_REASONS.include?(room.end_reason)
  end

  def system_notice(room)
    return unless handoff?(room)

    SYSTEM_NOTICES.fetch(room.end_reason)
  end
end
