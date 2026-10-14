# PATCH LOCAL (fork) - leva o nome novo de um item do cadastro de atendimento
# para custom_attributes das conversas (disparado por TicketCatalogRename).
#
# Sempre grava o nome ATUAL do banco, nunca o do momento do enfileiramento:
# repetir o job ou rodar dois renomes em ordem invertida termina no mesmo
# resultado. update_all de propósito: sem callback, sem webhook, sem mexer em
# updated_at (renomear um serviço não pode virar atividade em milhares de
# conversas). Conversa com código (servico_codigo...) é achada pelo código; sem
# código (ou item sem código ainda), pelo nome antigo exato.
#
# entries: [[id do item, valor antigo], ...] (no serviço, a subárvore inteira).
class TicketCatalog::RenameConversationsJob < ApplicationJob
  queue_as :medium

  BATCH_SIZE = 5000
  RENAME_SQL = "custom_attributes = jsonb_set(COALESCE(custom_attributes, '{}'::jsonb), ARRAY[?]::text[], to_jsonb(?::text))".freeze
  MODELS = %w[TicketService TicketCategory TicketStatus TicketJustification TicketCloseReason].freeze

  def perform(account_id, model_name, entries)
    model = MODELS.include?(model_name) ? model_name.constantize : raise(ArgumentError, "unknown catalog model #{model_name}")
    key = model.catalog_attribute.first
    taken_values = model.where(account_id: account_id).to_h { |item| [item.attribute_value, item.id] }

    entries.each do |item_id, old_value|
      item = model.find_by(id: item_id, account_id: account_id)
      next unless item

      # Outro item já ficou com o nome antigo: casar por nome pegaria conversa dele.
      match_old_name = taken_values[old_value].nil?
      rename(account_id, key, item, old_value, match_old_name)
    end
  end

  private

  def rename(account_id, key, item, old_value, match_old_name)
    code_key = TicketContract::CODE_KEYS.fetch(key)
    matchers = []
    matchers << ['custom_attributes ->> ? = ?', code_key, item.code] if item.code
    matchers << ['(custom_attributes ->> ? IS NULL AND custom_attributes ->> ? = ?)', code_key, key, old_value] if match_old_name
    return if matchers.empty?

    scope = Conversation.where(account_id: account_id)
                        .where(matchers.map { |matcher| sanitize(matcher) }.join(' OR '))
                        .where('custom_attributes ->> ? IS DISTINCT FROM ?', key, item.attribute_value)
    scope.in_batches(of: BATCH_SIZE) { |batch| batch.update_all([RENAME_SQL, key, item.attribute_value]) } # rubocop:disable Rails/SkipsModelValidations
  end

  def sanitize(matcher)
    ActiveRecord::Base.sanitize_sql_array(matcher)
  end
end
