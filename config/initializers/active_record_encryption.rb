require "active_support/key_generator"

generator = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base, iterations: 2**16)

derive = lambda do |label|
  generator.generate_key(label, 32).unpack1("H*")
end

Rails.application.config.active_record.encryption.primary_key = [
  ENV.fetch("HUSHPAIR_AR_ENCRYPTION_PRIMARY_KEY", derive.call("hushpair-ar-primary-key"))
]
Rails.application.config.active_record.encryption.deterministic_key = [
  ENV.fetch("HUSHPAIR_AR_ENCRYPTION_DETERMINISTIC_KEY", derive.call("hushpair-ar-deterministic-key"))
]
Rails.application.config.active_record.encryption.key_derivation_salt =
  ENV.fetch("HUSHPAIR_AR_ENCRYPTION_KEY_DERIVATION_SALT", derive.call("hushpair-ar-key-derivation-salt"))
Rails.application.config.active_record.encryption.support_unencrypted_data = true
