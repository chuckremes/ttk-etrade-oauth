require 'oauth'
require 'uri'

module TTK::ETrade::OAuth

  # Null object pattern
  #
  class Null

    def initialize(consumer_key: nil, consumer_secret: nil, redirect_url: nil, sandbox: false, &blk)
      nil
    end

    def authenticate(&blk)
      self
    end

    def get(path, query_params: {}, type: :json)
      nil
    end

    def renew
      false
    end

    def expired?
      time_left <= 0
    end

    def time_left(pretty: false)
      pretty ? pretty_time(0) : 0
    end

    def expire_time
      0
    end

    def _dump(level)
      h = {}
      h['access_token'] = nil
      h['redirect_url'] = ''
      h['access_token_start_time'] = 0
      h['sandbox'] = true

      Marshal.dump(h)
    end

    def self._load(string)
      obj = Marshal.load(string)

      NullSession
    end

    def inspect
      "#{self.class}: access_token.nil? [#{access_token.nil?}], time_left [#{time_left(pretty: true)}], sandbox: [#{sandbox}]"
    end


    private

    def pretty_time(seconds)
      "00:00:00"
    end
  end

  NullSession = Null.new
end
