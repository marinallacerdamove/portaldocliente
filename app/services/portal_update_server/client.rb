# PATCH LOCAL (fork) - aba Update Server da empresa (bases + licenças). Os
# dados moram no Portal do Cliente (Api::Internal::CompanyUpdateServersController,
# CompanyBasesController e CompanyLicensesController lá); aqui só repassa, pelo
# mesmo repasse com token interno e conta no header de PortalDocuments::Client.
# Toda chamada leva o nome do agente logado (X-Chatwoot-User-Name), pro
# histórico da empresa no Portal dizer quem mexeu.
class PortalUpdateServer::Client < PortalDocuments::Client
  def show
    call(:get, 'update_server')
  end

  def save_base(base_id, attributes)
    save('bases', base_id, base: attributes)
  end

  def save_license(license_id, attributes)
    save('licenses', license_id, license: attributes)
  end

  def save_module(module_id, attributes)
    save('license_modules', module_id, license_module: attributes)
  end

  def reorder_modules(ids)
    call(:post, 'license_modules/reorder', json_options(ids: ids))
  end

  private

  def headers
    super.merge('X-Chatwoot-User-Name' => agent_name)
  end

  # Sem quebra de linha: o nome vai num cabeçalho HTTP.
  def agent_name
    Current.user&.name.to_s.gsub(/[\r\n]+/, ' ').strip
  end

  def save(resource, record_id, body)
    return call(:post, resource, json_options(body)) if record_id.blank?

    call(:patch, "#{resource}/#{record_id.to_i}", json_options(body))
  end

  def json_options(body)
    { body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end
end
