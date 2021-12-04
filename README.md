# ttk-etrade-oauth
TradingToolKit ETrade Oauth support

A simple Ruby library for authenticating with the ETrade API. Only works for ETrade API v1 released circa 2018. The v0 API is not directly supported but it may work.

# Usage

```ruby
require 'launchy'
require 'oj'

session = TTK::ETrade::OAuth::Session.new(
  consumer_key: 'key', 
  consumer_secret: 'secret',
  redirect_url: 'oob', 
  sandbox: false) do |auth_url|

  Launchy.open(auth_url) # launch browser to authenticate and generate auth code

  print "Enter the code from the ETrade browser tab: "
  
  # last line of block must return the oauth_verifier code
  gets.chomp # read code from console
end

session = session.authenticate

session.renew if session.time_left < 300 # seconds

json_body = session.get('/v1/accounts/list')

xml_body = session.get('/v1/accounts/list', :xml)

json_body = session.get('/v1/accounts/123abc/balance', query_params: { instType: 'BROKERAGE', realTimeNAV: true })
```

# Resources

This [video on youtube](https://www.youtube.com/watch?v=6pGUFM9yqWo) was helpful.

# Plans

There are some patches for the `oauth` gem that need to be accepted upstream. The ETrade API uses OAuth 1.0 but for some reason the oauth gem provides an incompatible extension to that standard which causes POST and PUT operations to fail. The gem supports an additional key in the base signature called `oauth_body_hash` which computes a hash of any POST'ed or PUT'ed body; this is NOT part of the 1.0 standard. ETrade POST and PUT fails with a `signature_invalid` error because the signature includes that body hash. 

I've made a PR to allow for the body hash computation to be disabled. Waiting on upstream to accept it. In the meantime, I monkey patch the library to provide this support.

Secondly, I do not support the URL redirect logic yet. ETrade allows you to register a URL with them so the verification code can be auto-processed. For now I am forcing manual intervention. The library will go 1.0 when I decide to support that operation.

Lastly, there are no tests. I follow the progression of:

1. Make it work
2. Make it right
3. Make it fast

I've accomplished #1, so the "make it right" phase will include writing tests.
