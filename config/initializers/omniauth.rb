Rails.application.config.middleware.use OmniAuth::Builder do
  if ENV["GOOGLE_OAUTH_CLIENT_ID"].present? && ENV["GOOGLE_OAUTH_CLIENT_SECRET"].present?
    provider :google_oauth2,
             ENV.fetch("GOOGLE_OAUTH_CLIENT_ID"),
             ENV.fetch("GOOGLE_OAUTH_CLIENT_SECRET"),
             {
               scope: "openid,email,profile",
               prompt: "select_account",
               access_type: "online"
             }
  end
end

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true
