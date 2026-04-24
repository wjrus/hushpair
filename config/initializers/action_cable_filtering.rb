Rails.application.config.after_initialize do
  ActionCable.server.config.filter_parameters = Rails.application.config.filter_parameters
end
