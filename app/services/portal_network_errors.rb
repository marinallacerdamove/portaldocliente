# PATCH LOCAL: transport failures talking to the Portal (timeout, unreachable host, TLS, broken HTTP
# response). Every Portal client turns them into its own Error, which the screens show as 502 and the
# jobs retry, instead of a 500 (B85).
module PortalNetworkErrors
  # Below the 15 s Rack::Timeout cut (rack-timeout default; RACK_TIMEOUT_SERVICE_TIMEOUT is not set):
  # past it the screen got a 500 halfway instead of the client's "Portal unavailable" (B37).
  TIMEOUT_SECONDS = 12

  ALL = [Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError,
         Net::HTTPBadResponse, Net::ProtocolError].freeze
end
