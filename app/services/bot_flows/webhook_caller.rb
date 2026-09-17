# Chamada HTTP genérica do nó "Chamar webhook" - via SafeFetch (mesma
# proteção contra SSRF que Captain::Tools::HttpTool já usa pra webhooks
# configurados por admin), não HTTParty cru.
class BotFlows::WebhookCaller
  MAX_RESPONSE_SIZE = 256.kilobytes

  def initialize(node, vars, conversation)
    @node = node
    @vars = vars
    @conversation = conversation
  end

  def call
    url = interpolate(@node['url'])
    method = (@node['method'].presence || 'get').downcase.to_sym
    body = method == :post ? interpolate(@node['body_template']) : nil
    headers = (@node['headers'] || {}).merge(body.present? ? { 'Content-Type' => 'application/json' } : {})

    response_body = +''
    SafeFetch.fetch(
      url,
      method: method,
      body: body,
      headers: headers,
      sensitive_headers: headers.keys,
      max_bytes: MAX_RESPONSE_SIZE,
      validate_content_type: false
    ) { |result| response_body = result.tempfile.read }

    handle_response(response_body)
  rescue SafeFetch::Error => e
    Rails.logger.error("[BotFlows::WebhookCaller] #{e.class}: #{e.message}")
    ['error', @vars]
  end

  private

  def interpolate(template)
    BotFlows::Interpolation.render(template, variables: @vars, contact: @conversation.contact)
  end

  # SafeFetch::Fetcher already raises SafeFetch::HttpError for a non-2xx response (rescued above),
  # so reaching here means the HTTP call itself succeeded - the optional response-field check below
  # covers APIs that answer 200 with a body like {"found": false} (e.g. the CNPJ lookup).
  def handle_response(response_body)
    parsed = begin
      JSON.parse(response_body)
    rescue JSON::ParserError
      {}
    end

    check = @node['success_check']
    ok = check.blank? || parsed.dig(*check['field'].to_s.split('.')) == check['equals']

    [ok ? 'success' : 'error', @vars.merge(mapped_variables(parsed))]
  end

  def mapped_variables(parsed)
    (@node['response_mappings'] || []).each_with_object({}) do |mapping, acc|
      acc[mapping['variable_name']] = parsed.dig(*mapping['json_path'].to_s.split('.'))
    end
  end
end
