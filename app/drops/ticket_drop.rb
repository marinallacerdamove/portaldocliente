# PATCH LOCAL (fork) - {{ticket.*}} nas mensagens e macros: dados do ticket
# que o Portal grava nos custom attributes da conversa. Conversa que não veio
# do Portal (WhatsApp, ticket interno) usa o número da própria conversa.
class TicketDrop < BaseDrop
  def numero
    custom_attributes['ticket_id_externo'].presence || @obj.try(:display_id)
  end

  def assunto
    custom_attributes['assunto']
  end

  def servico
    custom_attributes['servico']
  end

  def tipo_de_solicitacao
    custom_attributes['tipo_de_solicitao']
  end

  def empresa
    custom_attributes['empresa']
  end

  def produto
    custom_attributes['produto']
  end

  # CPF/CNPJ da empresa do contato (Company#custom_attributes['cnpj']).
  def cpf_cnpj
    @obj.try(:contact)&.company&.custom_attributes&.dig('cnpj')
  end

  private

  def custom_attributes
    (@obj.try(:custom_attributes) || {}).transform_keys(&:to_s)
  end
end
