# PATCH LOCAL (fork) - Assistente (IA com base na wiki). A lógica e a base de
# conhecimento moram no Portal; o Chatwoot só repassa as chamadas do painel
# pelo backend (PortalAssistantController), com o mesmo token interno do bot
# de CNPJ - a chave da IA nunca chega no navegador.
#
# Só as contas listadas em PORTAL_ASSISTANT_ACCOUNT_IDS veem o Assistente: a
# wiki tem conteúdo interno que não pode aparecer pra conta de revenda.
class PortalAssistant::Client
  class Error < StandardError; end

  TIMEOUT_SECONDS = 90

  def self.account_ids
    ENV.fetch('PORTAL_ASSISTANT_ACCOUNT_IDS', '').split(',').map(&:strip).compact_blank.map(&:to_i)
  end

  def self.enabled_for?(account)
    account_ids.include?(account.id)
  end

  def initialize(account:, user:)
    @account = account
    @user = user
  end

  # [status HTTP, corpo já parseado]
  def request(method, path, params = {})
    options = { headers: headers, timeout: TIMEOUT_SECONDS }
    method == :get ? options[:query] = params : options[:body] = params.to_json
    response = HTTParty.send(method, "#{ENV.fetch('PORTAL_INTERNAL_API_URL')}/api/internal/assistant/#{path}", options)
    [response.code, response.parsed_response]
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
    raise Error, "#{e.class}: #{e.message}"
  end

  private

  def headers
    {
      'Content-Type' => 'application/json',
      'X-Internal-Token' => ENV.fetch('PORTAL_INTERNAL_API_TOKEN'),
      'X-Chatwoot-Account-Id' => @account.id.to_s,
      'X-Chatwoot-User-Id' => @user.id.to_s,
      'X-Chatwoot-User-Name' => @user.name.to_s
    }
  end
end
