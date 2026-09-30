# Versão "sem código" do que antes precisava ser montado à mão com dois
# blocos técnicos (Extrair padrão + Chamar webhook): acha um CNPJ dentro de
# uma resposta guardada e consulta o Portal do Cliente por ele. Endereço,
# token e formato da resposta ficam fixos aqui - a tela só pede de onde
# tirar o CNPJ, nada técnico.
class BotFlows::CnpjLookup
  CNPJ_REGEX = %r{\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2}}
  RESULT_VARIABLE = 'empresa_nome'.freeze

  def initialize(node, vars, conversation)
    @node = node
    @vars = vars
    @conversation = conversation
  end

  def call
    cnpj = @vars[@node['source_variable']].to_s[CNPJ_REGEX]
    return ['not_found', @vars] if cnpj.blank?

    webhook_node = {
      'url' => "#{ENV.fetch('PORTAL_INTERNAL_API_URL', '')}/api/internal/empresa_by_cnpj?cnpj=#{CGI.escape(cnpj)}",
      'method' => 'get',
      'headers' => { 'X-Internal-Token' => ENV.fetch('PORTAL_INTERNAL_API_TOKEN', '') },
      'success_check' => { 'field' => 'found', 'equals' => true },
      'response_mappings' => [{ 'json_path' => 'nome', 'variable_name' => RESULT_VARIABLE }]
    }

    handle, vars = BotFlows::WebhookCaller.new(webhook_node, @vars, @conversation).call
    # O webhook genérico fala "success"/"error" - esse nó promete
    # "found"/"not_found" pra fora (mesmo vocabulário do Extrair padrão),
    # então qualquer coisa que não seja sucesso conta como "não encontrado".
    return ['not_found', vars] unless handle == 'success'

    @conversation.save! if @conversation.assign_empresa(vars[RESULT_VARIABLE])
    ['found', vars]
  end
end
