require 'net/http'
require 'benchmark'
require 'json'

class HttpClient
  class HttpResponseError < StandardError
    attr_reader :hash
    def initialize hash={}
      super([hash[:response].code,?#,hash[:uri]].join) if hash[:uri]
      @hash = hash
    end
  end
  attr_reader :uri, :http, :key
  def initialize url, open_timeout = 5, read_timeout = 5, keep_alive_timeout = 5
    @uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port, nil, nil)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = open_timeout
    http.read_timeout = read_timeout
    http.keep_alive_timeout = keep_alive_timeout
    http.start
    @http = http
    @key = [uri.scheme, uri.host, uri.port].join
  end
  def self.instrumentation
    now = Time.now.to_i
    response = nil
    duration = "%.8f" % (
      Benchmark.realtime {
        response = yield
      }
    ).floor(8)
    raise HttpClient::HttpResponseError.new(nil, {
      timestamp: now,
      response: response,
      duration: duration
    }) unless ?2 == response.code[0]
    return response
  end
  def get path, header=nil
    begin
      return HttpClient.instrumentation {
        @http.get(path, header)
      }
    rescue HttpClient::HttpResponseError => hre
      raise HttpClient::HttpResponseError.new(hre.hash.merge({
        uri: @uri + path,
        method: :GET,
        header: header
      })
    end
  end
  def post path, body, header=nil
    begin
      return HttpClient.instrumentation {
        @http.post(path, body, header)
      }
    rescue HttpClient::HttpResponseError => hre
      raise HttpClient::HttpResponseError.new(hre.hash.merge({
        uri: @uri + path,
        method: :POST,
        parameter: body,
        header: header
      })
    end
  end
  def get_json path, header=nil
    JSON.parse(get(path, header).body)
  end
  def post_json path, hash, header={}
    header['Content-Type'] = 'application/json'
    JSON.parse(post(path, JSON.generate(hash), header).body)
  end
end
