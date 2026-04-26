class Api::V1::AnonymousSessionsController < Api::V1::BaseController
  def create
    anonymous_session = current_or_create_anonymous_session!(nickname: safe_nickname(params[:nickname]))

    render json: {
      anonymous_session: {
        id: anonymous_session.public_id,
        nickname: anonymous_session.current_nickname,
        status: anonymous_session.status
      }
    }, status: :created
  end
end
