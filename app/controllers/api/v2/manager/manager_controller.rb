class API::V2::Manager::ManagerController < API::V2::APIController
  skip_before_action :enforce_access_key!

  protected

  def authenticate!
    current_user ? true : not_authorized
  end

  def unauthenticate!
    current_user.destroy_session_token(auth_token)
    @current_user = nil
  end

  def render_session(token, ttl = User::SESSION_TTL)
    render json: { session: {
      token:      token.to_s,
      expires_at: Time.now + ttl
    } }, status: 200, serializer: nil
  end

  def render_error(error)
    status = error.delete(:status) || raise(ArgumentError, 'must supply :status')

    error[:code]   || raise(ArgumentError, 'must supply :code')
    error[:detail] || raise(ArgumentError, 'must supply :detail')

    render json: {
      error: error
    }, status: status, callback: params[:callback]

    false
  end
end
