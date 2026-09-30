# PATCH LOCAL (fork) - aba Documentos da empresa. Os arquivos moram no Portal
# do Cliente (Api::Internal::CompanyFilesController lá), achados pelo vínculo
# conta + empresa do Chatwoot; aqui só repassa, com o mesmo token interno do
# bot de CNPJ e do Assistente.
class PortalDocuments::Client
  class Error < StandardError; end

  TIMEOUT_SECONDS = 60

  def initialize(account:, company:)
    @account = account
    @company = company
  end

  def list
    call(:get, '')
  end

  def upload(file, categoria)
    call(:post, '', body: { file: file.tempfile, filename: file.original_filename, categoria: categoria }, multipart: true)
  end

  def update(file_id, observacao)
    call(:patch, "/#{file_id.to_i}", body: { observacao: observacao })
  end

  def destroy(file_id)
    call(:delete, "/#{file_id.to_i}")
  end

  def download(file_id)
    call(:get, "/#{file_id.to_i}/download")
  end

  private

  def call(method, path, options = {})
    url = "#{ENV.fetch('PORTAL_INTERNAL_API_URL')}/api/internal/companies/#{@company.id}/files#{path}"
    HTTParty.send(method, url, options.merge(headers: headers, timeout: TIMEOUT_SECONDS))
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
    raise Error, "#{e.class}: #{e.message}"
  end

  def headers
    { 'X-Internal-Token' => ENV.fetch('PORTAL_INTERNAL_API_TOKEN'), 'X-Chatwoot-Account-Id' => @account.id.to_s }
  end
end
