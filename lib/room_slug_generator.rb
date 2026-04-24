module RoomSlugGenerator
  ADJECTIVES = %w[
    amber
    calm
    cedar
    cloud
    dusk
    fern
    gentle
    hidden
    ivory
    juniper
    lucid
    mellow
    misty
    muted
    quiet
    silver
    soft
    still
    velvet
    warm
  ].freeze

  NOUNS = %w[
    anchor
    candle
    cove
    ember
    forest
    harbor
    lantern
    meadow
    mirror
    moon
    pine
    river
    shadow
    sparrow
    stone
    tide
    trail
    valley
    willow
    window
  ].freeze

  module_function

  def generate
    [
      ADJECTIVES.sample,
      ADJECTIVES.sample,
      NOUNS.sample,
      NOUNS.sample
    ].join("-")
  end
end
