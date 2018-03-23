FaradayWithRedirects = Faraday.new do |builder|
  builder.request :url_encoded
  builder.use FaradayMiddleware::FollowRedirects
  builder.adapter Faraday.default_adapter
end
