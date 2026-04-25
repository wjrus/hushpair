module Admin
  class SessionsController < ApplicationController
    def create
      auth = request.env["omniauth.auth"]
      email = auth&.dig("info", "email").to_s.downcase

      unless auth.present? && admin_email_allowed?(email)
        reset_session
        redirect_to admin_dashboard_path, alert: "That Google account is not allowed to access the admin panel."
        return
      end

      reset_session
      session[:admin_email] = email
      session[:admin_name] = auth.dig("info", "name").presence || email

      redirect_to admin_dashboard_path, notice: "Signed in to the admin panel."
    end

    def destroy
      reset_session
      redirect_to root_path, notice: "Signed out of the admin panel."
    end

    def failure
      redirect_to admin_dashboard_path, alert: "Google sign-in failed. Please try again."
    end
  end
end
