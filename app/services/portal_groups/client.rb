# PATCH LOCAL (fork) - Grupos de clientes. Os dados (empresas e contatos de
# cada grupo) moram no Portal do Cliente, que também calcula quem recebe agora
# (empresa ativa, contato ativo, com telefone); o cadastro é feito no Chatwoot,
# que lê e grava pela API interna do Portal com o mesmo token do bot de CNPJ, do
# Assistente e dos Documentos (mesmo padrão do Updater Server). Cada grupo
# pertence a UMA conta do Chatwoot (header X-Chatwoot-Account-Id). Usado pela
# tela Grupos (PortalGroupsController) e pelo público das campanhas de WhatsApp
# (Whatsapp::OneoffCampaignService).
class PortalGroups::Client
  # status: HTTP devolvido pelo Portal (nil em erro de rede). errors: lista de
  # mensagens do Portal num 422 (nome vazio ou repetido, por exemplo).
  class Error < StandardError
    attr_reader :status, :errors

    def initialize(message, status: nil, errors: nil)
      super(message)
      @status = status
      @errors = errors
    end
  end

  TIMEOUT_SECONDS = 60

  # user (opcional): o nome do agente vai no cabeçalho X-Chatwoot-User-Name; o
  # envio de campanha roda em job, sem usuário logado.
  def initialize(account:, user: nil)
    @account = account
    @user = user
  end

  # [{ 'id', 'name', 'automatic', 'active', 'empresas_count', 'contatos_count', 'recipients_count' }]
  # Sem all: só os ativos (público de campanha); com all: inclui os inativos (tela Grupos).
  def list(all: false)
    request(:get, 'client_groups', query: all ? { all: 1 } : {})['data']
  end

  # id é um inteiro ou 'todos' (grupo automático de todos os clientes ativos). Devolve também grupo inativo.
  def show(id)
    request(:get, "client_groups/#{ERB::Util.url_encode(id)}")
  end

  # Empresas e contatos avulsos da conta que podem entrar num grupo.
  def options
    request(:get, 'client_groups/options')
  end

  # attributes: { name: }
  def create(attributes)
    request(:post, 'client_groups', json_body(attributes))
  end

  # attributes: { name:, active:, empresa_ids:, partner_ids: }. As listas são a lista COMPLETA; ausente = não mexe.
  def update(id, attributes)
    request(:patch, "client_groups/#{ERB::Util.url_encode(id)}", json_body(attributes))
  end

  # [{ 'chatwoot_contact_id', 'name', 'phone' }] dos contatos DESTA conta que recebem agora
  def recipients(id)
    request(:get, "client_groups/#{ERB::Util.url_encode(id)}/recipients")['data']
  end

  private

  def request(method, path, options = {})
    response = HTTParty.send(method, "#{ENV.fetch('PORTAL_INTERNAL_API_URL')}/api/internal/#{path}",
                             options.merge(headers: headers.merge(options[:headers] || {}), timeout: TIMEOUT_SECONDS))
    raise error_for(response, path) unless response.success?

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise Error, "Portal devolveu uma resposta inválida em #{path}: #{e.message}"
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
    raise Error, "#{e.class}: #{e.message}"
  end

  def error_for(response, path)
    Error.new("Portal respondeu HTTP #{response.code} em #{path}", status: response.code, errors: validation_errors(response))
  end

  def validation_errors(response)
    return unless response.code == 422

    JSON.parse(response.body)['errors']
  rescue JSON::ParserError, TypeError
    nil
  end

  def json_body(attributes)
    { body: { client_group: attributes }.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  def headers
    base = { 'X-Internal-Token' => ENV.fetch('PORTAL_INTERNAL_API_TOKEN'), 'X-Chatwoot-Account-Id' => @account.id.to_s }
    @user ? base.merge('X-Chatwoot-User-Name' => agent_name) : base
  end

  # Sem quebra de linha: o nome vai num cabeçalho HTTP.
  def agent_name
    @user.name.to_s.gsub(/[\r\n]+/, ' ').strip
  end
end
