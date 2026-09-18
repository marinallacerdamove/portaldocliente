# Versão pública do "Consultar CNPJ no Portal": em vez de olhar só o que
# já está cadastrado no Portal, busca o CNPJ direto na base oficial da
# Receita Federal (via BrasilAPI, gratuita, sem chave/token). Pensado pro
# time comercial reconhecer um cliente novo antes mesmo de responder -
# razão social, CNAE, endereço e situação cadastral, tudo automático.
class BotFlows::ReceitaCnpjLookup
  CNPJ_REGEX = /\d{2}\.?\d{3}\.?\d{3}\/?\d{4}-?\d{2}/.freeze
  BASE_URL = 'https://brasilapi.com.br/api/cnpj/v1'.freeze

  RESPONSE_MAPPINGS = [
    { 'json_path' => 'razao_social', 'variable_name' => 'empresa_razao_social' },
    { 'json_path' => 'nome_fantasia', 'variable_name' => 'empresa_nome_fantasia' },
    { 'json_path' => 'cnae_fiscal_descricao', 'variable_name' => 'empresa_cnae' },
    { 'json_path' => 'descricao_situacao_cadastral', 'variable_name' => 'empresa_situacao' },
    { 'json_path' => 'porte', 'variable_name' => 'empresa_porte' },
    { 'json_path' => 'ddd_telefone_1', 'variable_name' => 'empresa_telefone' },
    { 'json_path' => 'data_inicio_atividade', 'variable_name' => 'empresa_data_abertura' },
    { 'json_path' => 'logradouro', 'variable_name' => 'empresa_logradouro' },
    { 'json_path' => 'numero', 'variable_name' => 'empresa_numero' },
    { 'json_path' => 'bairro', 'variable_name' => 'empresa_bairro' },
    { 'json_path' => 'municipio', 'variable_name' => 'empresa_municipio' },
    { 'json_path' => 'uf', 'variable_name' => 'empresa_uf' },
    { 'json_path' => 'cep', 'variable_name' => 'empresa_cep' }
  ].freeze

  def initialize(node, vars, conversation)
    @node = node
    @vars = vars
    @conversation = conversation
  end

  def call
    digits = @vars[@node['source_variable']].to_s[CNPJ_REGEX].to_s.gsub(/\D/, '')
    return ['not_found', @vars] if digits.blank?

    webhook_node = { 'url' => "#{BASE_URL}/#{digits}", 'method' => 'get', 'response_mappings' => RESPONSE_MAPPINGS }
    handle, vars = BotFlows::WebhookCaller.new(webhook_node, @vars, @conversation).call
    return ['not_found', vars] unless handle == 'success'

    ['found', vars.merge('empresa_endereco' => format_address(vars))]
  end

  private

  # O endereço vem em 6 variáveis separadas (mapeadas acima) - útil ter
  # cada pedaço à parte, mas também uma linha só pronta pra usar direto
  # numa mensagem, sem quem monta o fluxo ter que juntar tudo na mão.
  def format_address(vars)
    line = [vars['empresa_logradouro'], vars['empresa_numero']].reject(&:blank?).join(', ')
    line += " - #{vars['empresa_bairro']}" if vars['empresa_bairro'].present?
    line += " - #{vars['empresa_municipio']}/#{vars['empresa_uf']}" if vars['empresa_municipio'].present?
    line += " - CEP #{vars['empresa_cep']}" if vars['empresa_cep'].present?
    line
  end
end
