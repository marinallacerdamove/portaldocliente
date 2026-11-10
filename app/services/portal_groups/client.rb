# PATCH LOCAL (fork) - Grupos de clientes. O cadastro (empresas e contatos de
# cada grupo) mora no Portal do Cliente; ele também calcula quem recebe agora
# (empresa ativa, contato ativo, com telefone). O Chatwoot só consulta, com o
# mesmo token interno do bot de CNPJ, do Assistente e dos Documentos: a tela
# Grupos (PortalGroupsController) e o público das campanhas de WhatsApp
# (Whatsapp::OneoffCampaignService).
class PortalGroups::Client
  class Error < StandardError
    attr_reader :status

    def initialize(message, status: nil)
      super(message)
      @status = status
    end
  end

  TIMEOUT_SECONDS = 60

  def initialize(account:)
    @account = account
  end

  # [{ 'id', 'name', 'automatic', 'empresas_count', 'contatos_count', 'recipients_count' }]
  def list
    get('client_groups')['data']
  end

  # id é um inteiro ou 'todos' (grupo automático de todos os clientes ativos)
  def show(id)
    get("client_groups/#{ERB::Util.url_encode(id)}")
  end

  # [{ 'chatwoot_contact_id', 'name', 'phone' }] dos contatos DESTA conta que recebem agora
  def recipients(id)
    get("client_groups/#{ERB::Util.url_encode(id)}/recipients")['data']
  end

  private

  def get(path)
    response = HTTParty.get("#{ENV.fetch('PORTAL_INTERNAL_API_URL')}/api/internal/#{path}", headers: headers, timeout: TIMEOUT_SECONDS)
    raise Error.new("Portal respondeu HTTP #{response.code} em #{path}", status: response.code) unless response.success?

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise Error, "Portal devolveu uma resposta inválida em #{path}: #{e.message}"
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
    raise Error, "#{e.class}: #{e.message}"
  end

  def headers
    { 'X-Internal-Token' => ENV.fetch('PORTAL_INTERNAL_API_TOKEN'), 'X-Chatwoot-Account-Id' => @account.id.to_s }
  end
end
