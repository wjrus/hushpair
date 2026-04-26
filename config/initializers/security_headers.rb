Rails.application.configure do
  config.action_dispatch.default_headers.merge!(
    "Cross-Origin-Opener-Policy" => "same-origin",
    "Cross-Origin-Resource-Policy" => "same-origin",
    "Permissions-Policy" => [
      "camera=()",
      "geolocation=()",
      "microphone=()",
      "payment=()",
      "usb=()"
    ].join(", ")
  )
end
