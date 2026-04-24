require "digest"
require "securerandom"

module TokenDigest
  module_function

  def generate(length = 32)
    SecureRandom.base58(length)
  end

  def hexdigest(token)
    return if token.blank?

    Digest::SHA256.hexdigest(token)
  end
end
