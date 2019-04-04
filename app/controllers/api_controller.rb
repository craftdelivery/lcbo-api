class APIController < ApplicationController
  MAX_DEV_IPS       = 3
  RATE_LIMIT_WEB    = 1200
  RATE_LIMIT_NATIVE = 2400
  TOKEN_RE          = /\AToken[ ]+/i
  BASIC_RE          = /\ABasic[ ]+/i
  BASIC_AUTH        = ActionController::HttpAuthentication::Basic
  TOKEN_AUTH        = ActionController::HttpAuthentication::Token

  LOOPBACKS = %w[
    0.0.0.0
    127.0.0.1
    localhost
  ]

  CORS_HEADERS = {
    'Access-Control-Allow-Origin'  => '*',
    'Access-Control-Allow-Methods' => 'GET, HEAD, OPTIONS',
    'Access-Control-Allow-Headers' => %w[
      Origin
      Accept
      Authorization
      User-Agent
      X-Requested-With
    ].join(', '),
    'Access-Control-Expose-Headers' => %w[
      X-Rate-Limit-Count
      X-Rate-Limit-Max
      X-Rate-Limit-Reset
    ].join(', ')
  }

  class NotAuthorizedError < StandardError; end

  before_action \
    :set_api_headers,
    :record_api_hit,
    except: [:preflight_cors]

  after_action \
    :twerk_response_for_jsonp,
    :add_cors_headers

  clear_respond_to
  respond_to :json, :js

  def preflight_cors
    @enable_cors = true
    headers['Access-Control-Max-Age'] = 1.hour
    expires_in 1.hour, public: true
    head :ok
  end

  protected

  def verify_request!
    return true unless current_key

    if current_key[:kind] != 'web_client' || current_key[:domain].blank?
      params.delete(:callback)
      return true
    end

    @enable_cors = true

    if origin && (LOOPBACKS.include?(origin) || origin.include?(current_key[:domain]))
      true
    else
      render_error \
        status: 403,
        code: 'bad_origin',
        detail: I18n.t('bad_origin')
    end
  end

  def add_cors_headers
    return true unless @enable_cors
    headers.merge!(CORS_HEADERS)
    true
  end

  def origin
    @origin ||= begin
      origin = (request.headers['Origin'] || request.headers['Referer'])

      return if origin.blank?

      origin.downcase!

      if origin == 'null'
        origin = 'http://127.0.0.1'
      end

      uri = URI.parse(origin)

      case uri.scheme
      when 'http', 'https'
        uri.host
      else
        nil
      end
    rescue URI::InvalidURIError
      nil
    end
  end

  # This POS returns in any context and is a POS.
  def default_serializer(resource)
    nil
  end

  def get_auth_token
    header = request.authorization

    case header
    when TOKEN_RE
      token, _ = TOKEN_AUTH.token_and_options(request)
      token || header.sub(TOKEN_RE, '')
    when BASIC_RE
      _, token = BASIC_AUTH.user_name_and_password(request)
      token
    else
      params[:access_key]
    end
  end

  def auth_token
    @auth_token ||= Token.parse(get_auth_token)
  end

  def current_user
    @current_user ||= User.lookup(auth_token)
  end

  def current_key
    @current_key ||= Key.lookup(auth_token)
  end

  def account_info
    @account_info ||= begin
      user_id = if current_key
        current_key[:user_id]
      elsif current_user
        current_user.id
      end

      begin
        User.redis_load(user_id)
      rescue ActiveRecord::RecordNotFound
        raise NotAuthorizedError
      end
    end
  end

  def jsonp?
    (request.format && request.format.js?) && params[:callback].present?
  end

  def enforce_access_key!
    return true unless current_key

    return false unless enforce_request_pool!
    return false unless enforce_max_clients!
    return false unless enforce_rate_limit!

    true
  end

  def enforce_max_clients!
    key_id     = current_key[:id]
    kind       = current_key[:kind]
    in_devmode = current_key[:in_devmode] ? true : false
    max        = account_info[:max_dev_ips] || MAX_DEV_IPS
    redis_key  = Key.redis_hourly_ips_log_key(key_id)

    return true unless kind == 'web_client' && in_devmode

    result = $redis.multi do
      $redis.pfadd(redis_key, request.remote_ip)
      $redis.ttl(redis_key)
      $redis.pfcount(redis_key)
    end

    is_new = result[0]
    ttl    = result[1].to_i
    count  = result[2].to_i

    if ttl == -1
      $redis.expire(redis_key, 1.hour)
    end

    response.headers['X-Client-Limit-Max']   = max
    response.headers['X-Client-Limit-Count'] = count
    response.headers['X-Client-Limit-TTL']   = ttl

    if (count > max) && is_new
      render_error \
        status: 403,
        code: 'too_many_sessions',
        title: 'Maximum client sessions reached',
        detail: I18n.t('too_many_sessions', max: max, ttl: ttl)

      return false
    end

    true
  end

  def enforce_rate_limit!
    key_id     = current_key[:id]
    kind       = current_key[:kind]
    in_devmode = current_key[:in_devmode] ? true : false
    redis_key  = Key.redis_ip_requests_per_hour_key(key_id, request.remote_ip)

    return true unless (kind == 'web_client' && !in_devmode) || kind == 'native_client'

    # Enforce max requests per hour limit
    count = $redis.incr(redis_key).to_i
    max   = kind == 'web_client' ? RATE_LIMIT_WEB : RATE_LIMIT_NATIVE

    if count == 1
      $redis.expire(redis_key, 1.hour)
    end

    ttl = $redis.ttl(redis_key).to_i + 1

    response.headers['X-Rate-Limit-Max']   = max
    response.headers['X-Rate-Limit-Count'] = count
    response.headers['X-Rate-Limit-TTL']   = ttl
    response.headers['Retry-After']        = ttl

    if count > max
      render_error \
        code:   'rate_limited',
        title:  'Rate limit reached',
        detail: I18n.t('rate_limited', max: max, ttl: ttl),
        status: 428

      return false
    end

    true
  end

  def record_api_hit
    return true unless current_key
    return true if @current_hit

    now     = Time.now.utc
    cycle   = now.strftime('%Y-%m')
    member  = now.strftime('%Y-%m-%d')
    key_id  = current_key[:id]
    user_id = current_key[:user_id]

    user_total = nil
    key_total  = nil

    $redis.pipelined do
      user_total = $redis.incr User.redis_cycle_total_requests_key(user_id, cycle)
      $redis.zincrby User.redis_cycle_daily_request_totals_key(user_id, cycle), 1, member
      $redis.sadd    User.redis_cycles_key(user_id), cycle
      $redis.incr    User.redis_total_requests_key(user_id)

      key_total = $redis.incr Key.redis_cycle_total_requests_key(key_id, cycle)
      $redis.zincrby Key.redis_cycle_daily_request_totals_key(key_id, cycle), 1, member
      $redis.sadd    Key.redis_cycles_key(key_id), cycle
      $redis.incr    Key.redis_total_requests_key(key_id)
    end

    @current_hit = {
      user_total: user_total.value.to_i,
      key_total: key_total.value.to_i
    }

    true
  end

  def current_hit
    @current_hit
  end

  def feature_enabled?(flag)
    return false unless current_key
    account_info[flag] ? true : false
  end

  def enforce_feature_flag!(flag)
    if !current_key
      message = I18n.t('authorized_feature', action: I18n.t("authorized_features.#{flag}"))
      add_www_authenticate_header(message)
      render_error \
        code:   'unauthorized',
        title:  'Access Key Required',
        detail: message,
        status: 401
      return false
    end

    if !account_info[flag]
      render_error \
        code: 'unauthorized',
        title: 'Unsupported Feature',
        detail: I18n.t('unsupported_feature', feature: I18n.t("supported_features.#{flag}")),
        status: 403
      return false
    end

    return true
  end

  def enforce_request_pool!
    now   = Time.now
    max   = account_info[:request_pool_size]
    count = current_hit[:user_total]
    ttl   = now.end_of_month.to_i - now.to_i

    response.headers['X-Request-Pool-Size']  = max
    response.headers['X-Request-Pool-Count'] = count
    response.headers['X-Request-Pool-TTL']   = ttl
    response.headers['Retry-After']          = ttl

    if count > max
      render_error \
        code:   'too_many_requests',
        title:  'Exceeded monthly request pool',
        detail: I18n.t('too_many_requests', max: max),
        status: 429

      return false
    end

    true
  end

  def api_version
    raise NotImplementedError
  end

  def twerk_response_for_jsonp
    return true unless jsonp?
    response.headers['Content-Type'] = 'text/javascript'
    response.status = 200
    true
  end

  def set_api_headers
    response.headers['X-LCBO-API-Version'] = api_version
    true
  end

  def render_error(error)
    status = error.delete(:status) || raise(ArgumentError, 'must supply :status')

    error[:code]   || raise(ArgumentError, 'must supply :code')
    error[:detail] || raise(ArgumentError, 'must supply :detail')

    render json: {
      errors: [error]
    }, status: status, callback: params[:callback]

    false
  end

  def add_www_authenticate_header(message = nil)
    parts = ['Token realm="LCBO API"']
    parts << "message=\"#{message.gsub('"', '""')}\"" if message

    headers['WWW-Authenticate'] = parts.join(' ')
  end

  def not_authorized
    message = I18n.t('unauthorized')

    add_www_authenticate_header(message)

    render_error \
      code:   'unauthorized',
      title:  'Unauthorized',
      detail: message,
      status: 401
  end
end
