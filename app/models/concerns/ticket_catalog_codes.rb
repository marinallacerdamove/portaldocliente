# PATCH LOCAL (fork) - a conversa guarda, junto do NOME de cada cadastro de
# atendimento escolhido (servico, tipo_de_solicitao, status_atendimento,
# justificativa, motivo_encerramento), o CÓDIGO do item em chaves ocultas
# (servico_codigo...; TicketContract::CODE_KEYS). O nome é o que filtros,
# automações e relatórios leem; o código é o que sobrevive a renomear o item.
#
# Por cadastro, quando o nome ou o código mudou neste save:
#   1. nome vazio: remove o código (a menos que o código tenha mudado e exista:
#      quem manda só o código, como uma integração, recebe o nome pelo passo 2);
#   2. código mudou e existe no cadastro: nome = valor atual do item (código vence);
#   3. nome existe no cadastro: código = o do item;
#   4. código presente e existe, mas o nome não existe (tela desatualizada regravou
#      um nome antigo): nome = valor atual do item;
#   5. senão, nome órfão: fica sem código.
# 1, 2 e 4 (nome a partir do código) rodam ANTES do TicketStatusSync, que lê o
# nome do status; 1, 3 e 5 (código a partir do nome) rodam DEPOIS, pra pegar o
# status e a justificativa que o próprio TicketStatusSync ajustou.
# Sem códigos no cadastro e sem chave de código na conversa não faz nada (e nem
# consulta o cadastro, exceto a checagem barata de "há algum código").
module TicketCatalogCodes
  extend ActiveSupport::Concern

  CATALOG_ASSOCIATIONS = {
    TicketContract::SERVICE_KEY => :ticket_services,
    TicketContract::CATEGORY_KEY => :ticket_categories,
    TicketContract::STATUS_KEY => :ticket_statuses,
    TicketContract::JUSTIFICATION_KEY => :ticket_justifications,
    TicketContract::CLOSE_REASON_KEY => :ticket_close_reasons
  }.freeze

  included do
    before_save :normalize_catalog_names_from_codes, prepend: true
    before_save :derive_catalog_codes_from_names
  end

  private

  def normalize_catalog_names_from_codes
    each_changed_catalog do |name_key, code_key, scope|
      name, code = catalog_pair(name_key, code_key)
      item = scope.find_by(code: code) if code.present?
      if item && (catalog_value_changed?(code_key) || (name.present? && scope.for_attribute_value(name).nil?))
        set_catalog_attribute(name_key, item.attribute_value)
      elsif name.blank?
        remove_catalog_code(code_key)
      end
    end
  end

  def derive_catalog_codes_from_names
    each_changed_catalog do |name_key, code_key, scope|
      name, code = catalog_pair(name_key, code_key)
      next remove_catalog_code(code_key) if name.blank?

      item = scope.for_attribute_value(name)
      if item&.code
        set_catalog_attribute(code_key, item.code) unless item.code == code
      else
        remove_catalog_code(code_key)
      end
    end
  end

  def each_changed_catalog
    return unless account

    CATALOG_ASSOCIATIONS.each do |name_key, association|
      code_key = TicketContract::CODE_KEYS.fetch(name_key)
      next unless catalog_value_changed?(name_key) || catalog_value_changed?(code_key)

      scope = account.public_send(association)
      next unless custom_attributes.to_h.key?(code_key) || scope.where.not(code: nil).exists?

      yield name_key, code_key, scope
    end
  end

  def catalog_pair(name_key, code_key)
    [custom_attributes.to_h[name_key].to_s.squish, custom_attributes.to_h[code_key].to_s.strip]
  end

  def catalog_value_changed?(key)
    custom_attributes.to_h[key] != custom_attributes_was.to_h[key]
  end

  def set_catalog_attribute(key, value)
    self.custom_attributes = custom_attributes.to_h.merge(key => value)
  end

  def remove_catalog_code(code_key)
    self.custom_attributes = custom_attributes.to_h.except(code_key) if custom_attributes.to_h.key?(code_key)
  end
end
