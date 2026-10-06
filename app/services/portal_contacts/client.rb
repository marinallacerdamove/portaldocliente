# PATCH LOCAL (fork) - "Cadastrar contato" da lateral da conversa: cadastra o
# solicitante como usuário do Portal (POST /api/internal/contact_registrations,
# ver Integration::ChatwootContactRegistration no Portal). Mesmo token e mesma
# conta por header de PortalDocuments::Client.
class PortalContacts::Client
  class Error < StandardError; end

  TIMEOUT_SECONDS = 30

  Response = Struct.new(:status, :body, keyword_init: true)

  def initialize(account:)
    @account = account
  end

  def register(contact:, conversation:, name:, email:, phone:)
    res = HTTParty.post(
      "#{ENV.fetch('PORTAL_INTERNAL_API_URL')}/api/internal/contact_registrations",
      body: {
        chatwoot_contact_id: contact.id, chatwoot_company_id: contact.company_id,
        name: name, email: email, phone: phone, conversation_id: conversation.display_id
      }.to_json,
      headers: headers, timeout: TIMEOUT_SECONDS
    )
    Response.new(status: res.code, body: res.parsed_response.is_a?(Hash) ? res.parsed_response : {})
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
    raise Error, "#{e.class}: #{e.message}"
  end

  private

  def headers
    { 'X-Internal-Token' => ENV.fetch('PORTAL_INTERNAL_API_TOKEN'), 'X-Chatwoot-Account-Id' => @account.id.to_s,
      'Content-Type' => 'application/json' }
  end
end
