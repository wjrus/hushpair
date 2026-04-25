class ApplicationController < ActionController::Base
  include AnonymousSessionSupport
  before_action :ensure_client_instance_id!
  helper_method :admin_signed_in?, :current_admin_email

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def admin_signed_in?
    current_admin_email.present?
  end

  def current_admin_email
    session[:admin_email].presence
  end

  def allowed_admin_emails
    ENV.fetch("ADMIN_USER", "wjr@wjr.us").split(",").map { |email| email.strip.downcase }.reject(&:blank?)
  end

  def admin_email_allowed?(email)
    allowed_admin_emails.include?(email.to_s.downcase)
  end
end
