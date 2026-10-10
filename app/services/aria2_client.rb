require "net/http"
require "json"
require "securerandom"

# Minimal client for aria2's JSON-RPC interface.
# https://aria2.github.io/manual/en/html/aria2c.html#rpc-interface
class Aria2Client
  class Error < StandardError; end

  def initialize(url: ENV.fetch("ARIA2_RPC_URL", "http://localhost:6800/jsonrpc"),
                 secret: ENV["ARIA2_RPC_SECRET"])
    @uri = URI(url)
    @secret = secret.presence
  end

  def call(method, *params)
    response = post(method: method, params: with_token(params))
    raise Error, response["error"]["message"] if response["error"]

    response["result"]
  end

  # Runs several calls in one request.
  # Returns one entry per call: the result, or an Error.
  def multicall(calls)
    return [] if calls.empty?

    # The secret goes inside each call, not on system.multicall itself.
    payload = calls.map { |method, *params| { methodName: method, params: with_token(params) } }
    response = post(method: "system.multicall", params: [payload])
    raise Error, response["error"]["message"] if response["error"]

    response["result"].map do |r|
      r.is_a?(Hash) && r["message"] ? Error.new(r["message"]) : Array(r).first
    end
  end

  def add_uri(url, options = {})
    call("aria2.addUri", [url], options.transform_keys(&:to_s).transform_values(&:to_s))
  end

  private

  def with_token(params)
    @secret ? ["token:#{@secret}", *params] : params
  end

  def post(body)
    http = Net::HTTP.new(@uri.host, @uri.port)
    http.open_timeout = 3
    http.read_timeout = 15
    res = http.post(@uri.path.presence || "/jsonrpc",
                    body.merge(jsonrpc: "2.0", id: SecureRandom.hex(4)).to_json,
                    "Content-Type" => "application/json")
    JSON.parse(res.body)
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
    raise Error, "aria2 is not reachable at #{@uri} (#{e.class.name.demodulize})"
  rescue JSON::ParserError
    raise Error, "aria2 returned an invalid response (HTTP #{res&.code})"
  end
end
