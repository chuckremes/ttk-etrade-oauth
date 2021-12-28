# class OAuth::Client::Helper
#
#   def hash_body
#     nil #@options[:body_hash] = OAuth::Signature.body_hash(@request, :parameters => oauth_parameters)
#   end
#
# end

# module OAuth
#   # required parameters, per sections 6.1.1, 6.3.1, and 7
#   PARAMETERS = %w(oauth_callback oauth_consumer_key oauth_token
#     oauth_signature_method oauth_timestamp oauth_nonce oauth_verifier
#     oauth_version oauth_signature)
# end

module OAuth
  class Consumer
    @@default_options = {
      # Signature method used by server. Defaults to HMAC-SHA1
      signature_method: "HMAC-SHA1",

      # default paths on site. These are the same as the defaults set up by the generators
      request_token_path: "/oauth/request_token",
      authenticate_path: "/oauth/authenticate",
      authorize_path: "/oauth/authorize",
      access_token_path: "/oauth/access_token",

      proxy: nil,
      # How do we send the oauth values to the server see
      # https://oauth.net/core/1.0/#consumer_req_param for more info
      #
      # Possible values:
      #
      #   :header - via the Authorize header (Default) ( option 1. in spec)
      #   :body - url form encoded in body of POST request ( option 2. in spec)
      #   :query_string - via the query part of the url ( option 3. in spec)
      scheme: :header,

      # Default http method used for OAuth Token Requests (defaults to :post)
      http_method: :post,

      # Add a custom ca_file for consumer
      # :ca_file       => '/etc/certs.pem'

      # Possible values:
      #
      # nil, false - no debug output
      # true - uses $stdout
      # some_value - uses some_value
      debug_output: nil,

      # Defaults to producing a body_hash as part of the signature but
      # can be disabled since it's not officially part of the OAuth 1.0
      # spec. Possible values are true and false
      body_hash_enabled: true,

      oauth_version: "1.0"
    }

    def create_signed_request(http_method, path, token = nil, request_options = {}, *arguments)
      request = create_http_request(http_method, path, *arguments)
      sign!(request, token, request_options)
      debug(request) if $TTK_DEBUG
      request
    end

    def debug(request)
      STDERR.puts '= REQ PATH ='
      STDERR.puts request.path
      STDERR.puts '= REQ HEADERS ='
      request.each_header do |header, values|
        STDERR.puts "\t#{header}: #{values.inspect}"
      end
      STDERR.puts '= REQ BODY ='
      STDERR.puts request.body
      STDERR.puts '= REQ END ='
    end
  end
end

module Net
  class HTTPGenericRequest
    def oauth!(http, consumer = nil, token = nil, options = {})
      helper_options = oauth_helper_options(http, consumer, token, options)
      @oauth_helper = OAuth::Client::Helper.new(self, helper_options)
      @oauth_helper.amend_user_agent_header(self)
      p 'helper options', helper_options if $TTK_DEBUG
      @oauth_helper.hash_body if oauth_body_hash_required?(helper_options)
      send("set_oauth_#{helper_options[:scheme]}")
    end

    def signature_base_string(http, consumer = nil, token = nil, options = {})
      helper_options = oauth_helper_options(http, consumer, token, options)
      @oauth_helper = OAuth::Client::Helper.new(self, helper_options)
      p 'helper options', helper_options if $TTK_DEBUG
      @oauth_helper.hash_body if oauth_body_hash_required?(helper_options)
      @oauth_helper.signature_base_string
    end

    def oauth_helper_options(http, consumer, token, options)
      { request_uri: oauth_full_request_uri(http, options),
        consumer: consumer,
        token: token,
        scheme: "header",
        signature_method: nil,
        nonce: nil,
        timestamp: nil,
        body_hash_enabled: true }.merge(options)
    end

    def oauth_body_hash_required?(options)
      !@oauth_helper.token_request? && request_body_permitted? && !content_type.to_s.downcase.start_with?("application/x-www-form-urlencoded") && options[:body_hash_enabled]
    end
  end
end

