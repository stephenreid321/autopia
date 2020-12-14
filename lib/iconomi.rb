class Iconomi
  def self.get(path)
    t = DateTime.now.strftime('%Q')

    method = 'GET'
    message = t + method.upcase + path

    signature = Base64.encode64(
      OpenSSL::HMAC.digest(
        'sha512',
        ENV['ICN_SECRET'],
        message
      )
    ).split.join #  to remove newlines introduced by base64 encoding

    agent = Mechanize.new
    agent.request_headers = {
      'ICN-API-KEY' => ENV['ICN_API_KEY'],
      'ICN-SIGN' => signature,
      'ICN-TIMESTAMP' => t
    }
    agent.get('https://api.iconomi.com' + path).body
  end

  def self.post(path, request_body)
    t = DateTime.now.strftime('%Q')

    method = 'POST'
    message = t + method.upcase + path + request_body

    signature = Base64.encode64(
      OpenSSL::HMAC.digest(
        'sha512',
        ENV['ICN_SECRET'],
        message
      )
    ).split.join #  to remove newlines introduced by base64 encoding

    agent = Mechanize.new
    agent.request_headers = {
      'ICN-API-KEY' => ENV['ICN_API_KEY'],
      'ICN-SIGN' => signature,
      'ICN-TIMESTAMP' => t
    }
    agent.post('https://api.iconomi.com' + path, request_body, { 'Content-Type' => 'application/json' }).body
  end
end
