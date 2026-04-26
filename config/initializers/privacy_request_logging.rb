require "privacy_ip_redactor"

module HushpairPrivacyRequestLogging
  private

  def started_request_message(request)
    format(
      'Started %s "%s" for %s at %s',
      request.raw_request_method,
      request.filtered_path,
      PrivacyIpRedactor.redact(request.remote_ip),
      Time.now
    )
  end
end

Rails::Rack::Logger.prepend(HushpairPrivacyRequestLogging)
