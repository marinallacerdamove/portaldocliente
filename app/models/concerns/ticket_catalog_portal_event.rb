# PATCH LOCAL (fork) - mudança feita aqui (tela do Chatwoot) num item do cadastro
# sincronizado com o Portal do Cliente sai como o evento `ticket_catalog.updated`;
# mudança que veio do próprio Portal (`portal_sync`) não volta.
module TicketCatalogPortalEvent
  extend ActiveSupport::Concern

  included do
    after_commit :dispatch_portal_event, on: [:create, :update], unless: :portal_sync
  end

  attr_accessor :portal_sync

  # Troca uma lista N:N (tipos do serviço, status da justificativa) e, se a lista
  # mudou, anota o campo do contrato e renova updated_at (a troca da associação
  # sozinha não mexe no registro, e o Portal ordena as versões por updated_at).
  def replace_synced_association(association, records, contract_key)
    changed = public_send(association).map(&:id).sort != records.map(&:id).sort
    public_send("#{association}=", records)
    return unless changed

    (@changed_associations ||= []) << contract_key
    self.updated_at = Time.current
  end

  private

  def dispatch_portal_event
    keys = portal_changed_keys
    return if keys.empty?

    Rails.configuration.dispatcher.dispatch(Events::Types::TICKET_CATALOG_UPDATED, Time.zone.now, item: self, changed_keys: keys)
  ensure
    @changed_associations = nil
  end

  # Item novo vai inteiro; item editado, só os campos do contrato que mudaram.
  def portal_changed_keys
    fields = TicketCatalog::SyncFields.fields(TicketCatalog::SyncFields.key_for(self.class.name))
    return fields if saved_change_to_id?

    changed = saved_changes.keys.map { |column| TicketCatalog::SyncFields::COLUMN_REFERENCES.fetch(column, column) }
    (changed | Array(@changed_associations)) & fields
  end
end
