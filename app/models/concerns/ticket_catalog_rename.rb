# PATCH LOCAL (fork) - renomear um item do cadastro de atendimento (ou, no
# serviço, mudar de pai) propaga o nome novo para os dados vivos que guardam o
# nome: conversas (custom_attributes, em job, fora da transação) e regras de
# exibição, macros e automações (troca exata antigo -> novo, na mesma transação
# do rename). Antes só a lista do atributo de conversa era regravada e as
# conversas ficavam com valor fora da lista.
module TicketCatalogRename
  extend ActiveSupport::Concern

  included do
    after_update :rename_catalog_dependents, if: :catalog_renamed?
    after_update_commit :enqueue_conversation_rename
    after_rollback { @pending_conversation_rename = nil }
  end

  private

  def catalog_renamed?
    saved_changes.key?('name') || saved_changes.key?('parent_id')
  end

  # [[id, valor antigo, valor novo], ...] de tudo que mudou de nome neste save:
  # o item e, no serviço, a subárvore (ver TicketService).
  def catalog_rename_entries
    [[id, name_before_last_save, attribute_value]]
  end

  def rename_catalog_dependents
    entries = catalog_rename_entries.reject { |_id, old_value, new_value| old_value == new_value }
    return if entries.empty?

    @pending_conversation_rename = entries.map { |item_id, old_value, _new_value| [item_id, old_value] }
    TicketCatalog::DependentsRename.new(account_id, self.class.catalog_attribute.first,
                                        entries.to_h { |_item_id, old_value, new_value| [old_value, new_value] }).call
  end

  def enqueue_conversation_rename
    return if @pending_conversation_rename.blank?

    TicketCatalog::RenameConversationsJob.perform_later(account_id, self.class.name, @pending_conversation_rename)
    @pending_conversation_rename = nil
  end
end
