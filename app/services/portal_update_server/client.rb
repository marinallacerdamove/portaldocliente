# PATCH LOCAL (fork) - aba Update Server da empresa (bases + licenças). Os
# dados moram no Portal do Cliente (Api::Internal::CompanyUpdateServersController,
# CompanyBasesController e CompanyLicensesController lá); aqui só repassa, pelo
# mesmo repasse com token interno e conta no header de PortalDocuments::Client.
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

  private

  def save(resource, record_id, body)
    return call(:post, resource, json_options(body)) if record_id.blank?

    call(:patch, "#{resource}/#{record_id.to_i}", json_options(body))
  end

  def json_options(body)
    { body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end
end
