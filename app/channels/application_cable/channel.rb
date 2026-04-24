module ApplicationCable
  class Channel < ActionCable::Channel::Base
    private

    def transmit(data, via: nil)
      logger.debug do
        filtered_data = parameter_filter.filter(data)
        status = "#{self.class.name} transmitting #{filtered_data.inspect.truncate(300)}"
        status += " (via #{via})" if via
        status
      end

      payload = { channel_class: self.class.name, data: data, via: via }
      ActiveSupport::Notifications.instrument("transmit.action_cable", payload) do
        connection.transmit identifier: @identifier, message: data
      end
    end
  end
end
