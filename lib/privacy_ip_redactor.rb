require "ipaddr"

module PrivacyIpRedactor
  module_function

  def redact(value)
    ip = IPAddr.new(value.to_s)

    if ip.ipv4?
      octets = ip.to_s.split(".")
      "#{octets[0]}.#{octets[1]}.#{octets[2]}.0"
    else
      hextets = ip.to_string.split(":")
      "#{hextets.first(4).join(":")}::"
    end
  rescue IPAddr::InvalidAddressError
    "unknown"
  end
end
