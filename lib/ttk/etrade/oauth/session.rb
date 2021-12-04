require 'uri'
require 'tzinfo'

module TTK::ETrade::OAuth
  class Session

    UnknownHeaderType = Class.new(StandardError)

    JSON_HEADER = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    XML_HEADER  = { 'Accept' => 'application/xml', 'Content-Type' => 'application/xml' }
    HTTPOK      = '200'
    TZ          = TZInfo::Timezone.get('US/Eastern')

    def initialize(consumer_key:, consumer_secret:, redirect_url:, sandbox: false, &blk)
      setup_urls(sandbox)
      @consumer_key    = consumer_key
      @consumer_secret = consumer_secret
      @redirect_url    = redirect_url

      # the logic to retrieve the authentication code; can't be persisted / stored
      @retrieve_auth_code_block = blk
    end

    # Creates an OAuth session, retrieves a request_token, and contacts the generated 
    # authorization URL. When using 'oob' as the callback, the user must manually
    # intervene to copy/paste the code from the authentication.
    #
    # When given a redirect URL to an automated process, it eliminates the manual work.
    #
    def authenticate(&blk)
      @consumer = OAuth::Consumer.new(consumer_key,
                                      consumer_secret,
                                      :site          => base_url,
                                      :http_method   => :get,
                                      :authorize_url => @authorize_url,
                                      :body_hash_enabled => false)

      request_token = consumer.get_request_token({ :oauth_callback => redirect_url })

      # For whatever reason, ETrade renames the 'oauth_token' parameter to just 'token'
      auth_url = request_token.authorize_url({ key: consumer_key, token: request_token.token }).gsub('outh_token', 'token')

      oauth_verifier           = (blk || @retrieve_auth_code_block).call(auth_url)
      @access_token_start_time = Time.now
      @access_token            = request_token.get_access_token(:oauth_verifier => oauth_verifier)
      STDERR.puts "consumer_key: #{consumer_key}"
      STDERR.puts "consumer_secret: #{consumer_secret}"
      STDERR.puts "token key: #{@access_token.token}"
      STDERR.puts "token secret: #{@access_token.secret}"
      self
    end

    def get(path, query_params: {}, type: :json)
      uri = sanitize_url(path, query_params)
      # pp 'get', uri.to_s
      response = access_token.get(uri, header(type))
      error_check(response)
      response
    end

    def post(path, body:, query_params: {}, type: :json)
      uri = sanitize_url(path, query_params)
      pp 'post', uri.to_s, body, header(type)
      response = access_token.post(uri, body, header(type))
      error_check(response)
      response
    end

    def put(path, body:, query_params: {}, type: :json)
      uri = sanitize_url(path, query_params)
      # pp 'put', uri.to_s
      response = access_token.put(uri, body, header(type))
      error_check(response)
      response
    end

    def delete(path, query_params: {}, type: :json)
      uri = sanitize_url(path, query_params)
      # pp 'delete', uri.to_s
      response = access_token.delete(uri, header(type))
      error_check(response)
      response
    end

    def renew
      response                 = access_token.get('/oauth/renew_access_token')
      valid                    = error_check(response)
      @access_token_start_time = Time.now if valid
      valid
    rescue OAuth::Problem => e # likely OAuth::Problem - token_rejected
      @access_token_start_time = Time.at(0)
      false
    end

    def expired?
      time_left <= 0
    end

    def time_left(pretty: false)
      return 0 unless access_token
      left = expire_time - Time.now
      pretty ? pretty_time(left) : left
    end

    def expire_time
      return 0 unless @access_token_start_time

      # set for 118 minutes into the future... token expires after 120m
      # alternately, detect midnight EST and truncate to that time
      @expire_time ||= begin
                         atst = @access_token_start_time
                         e1   = atst + (60 * 118)
                         e2   = TZ.local_time(atst.year, atst.month, atst.day, 23, 59, 59)
                         # if current time is past midnight, it's a new day so ignore the midnight value
                         e2   = e1 if Time.now.utc > e2.utc
                         [e1, e2].min
                       end
    end

    def _dump(level)
      h                            = {}
      h['access_token']            = access_token
      h['redirect_url']            = redirect_url
      h['access_token_start_time'] = access_token_start_time
      h['sandbox']                 = sandbox

      STDERR.puts "Dumping a real session, #{h.inspect}"
      Marshal.dump(h)
    end

    def self._load(string)
      obj          = Marshal.load(string)
      access_token = obj['access_token']
      redirect_url = obj['redirect_url']
      sandbox      = obj['sandbox']

      return TTK::ETrade::OAuth::NullSession if access_token.nil?

      instance = new(consumer_key:    access_token.consumer.key,
                     consumer_secret: access_token.consumer.secret,
                     redirect_url:    redirect_url,
                     sandbox:         sandbox)

      instance.instance_variable_set(:@access_token, access_token)
      instance.instance_variable_set(:@access_token_start_time, obj['access_token_start_time'])
      instance.instance_variable_set(:@consumer, access_token.consumer)
      instance
    end

    def inspect
      "#{self.class}: access_token.nil? [#{access_token.nil?}], time_left [#{time_left(pretty: true)}], sandbox: [#{sandbox}]"
    end

    private

    attr_reader :consumer_key, :consumer_secret, :redirect_url, :base_url, :sandbox
    attr_reader :consumer, :request_token, :access_token, :access_token_start_time

    def setup_urls(sandbox)
      @sandbox = sandbox
      segment  = sandbox ? 'sb' : ''

      @request_token_url = "https://api#{segment}.etrade.com/oauth/request_token"
      @access_token_url  = "https://api#{segment}.etrade.com/oauth/access_token"
      @authorize_url     = "https://us.etrade.com/e/t/etws/authorize"
      @base_url          = "https://api#{segment}.etrade.com"
    end

    def header(type)
      case type
      when :json then JSON_HEADER
      when :xml then XML_HEADER
      else
        raise UnknownHeaderType.new("Do not understand header type: #{type.inspect}")
      end
    end

    def error_check(response)
      # does nothing
      # error handling is the caller's responsibility
      true
    end

    def sanitize_url(path, query_params)
      uri       = URI.parse(base_url + path)
      uri.query = URI.encode_www_form(query_params) unless (query_params || {}).empty?
      uri.to_s
    end

    def pretty_time(seconds)
      Time.at(seconds).utc.strftime("%H:%M:%S")
    end
  end
end
