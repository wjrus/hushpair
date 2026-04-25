module Admin
  class DashboardController < ApplicationController
    def show
      unless admin_signed_in?
        render "admin/sessions/new", status: :unauthorized
        return
      end

      @metrics = DashboardMetrics.new(
        preset: params[:preset],
        start_date: params[:start_date],
        end_date: params[:end_date]
      )
    end
  end
end
