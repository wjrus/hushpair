module Admin
  class DashboardController < ApplicationController
    before_action :require_admin!

    def show
      @metrics = DashboardMetrics.new(
        preset: params[:preset],
        start_date: params[:start_date],
        end_date: params[:end_date]
      )
    end

    def clear_match_pairs
      deleted_count = MatchPair.delete_all
      redirect_to admin_dashboard_path, notice: "Cleared #{deleted_count} matching #{'pair'.pluralize(deleted_count)}."
    end

    private

    def require_admin!
      return if admin_signed_in?

      render "admin/sessions/new", status: :unauthorized
    end
  end
end
