# PATCH LOCAL: transport failures talking to the Portal (timeout, unreachable host, TLS, broken HTTP
# response). Every Portal client turns them into its own Error, which the screens show as 502 and the
# jobs retry, instead of a 500 (B85).
module PortalNetworkErrors
  ALL = [Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError,
         Net::HTTPBadResponse, Net::ProtocolError].freeze
end
