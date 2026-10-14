# PATCH LOCAL (fork) - corpo do webhook `ticket_catalog_updated` (item do
# cadastro de atendimento criado ou editado aqui, a caminho do Portal do
# Cliente). Mesmo formato que o Portal le em Integration::Handlers::CatalogItemUpdated.
class TicketCatalog::WebhookPayload
  EVENT = 'ticket_catalog_updated'.freeze

  def initialize(item, changed_keys)
    @item = item
    @changed_keys = changed_keys
    @key = TicketCatalog::SyncFields.key_for(item.class.name)
  end

  def as_json(*)
    {
      event: EVENT,
      account: { id: @item.account_id, name: @item.account.name },
      catalog: @key,
      item: item_data,
      changed_keys: @changed_keys,
      updated_at: @item.updated_at.iso8601(6)
    }
  end

  private

  def item_data
    columns = TicketCatalog::SyncFields::COLUMNS.fetch(@key).index_with { |column| @item.public_send(column) }
    { id: @item.id, code: @item.code }.merge(columns).merge(references)
  end

  # Itens sem código (ainda sem Portal) saem da lista: voltam quando o código chegar.
  def references
    case @key
    when 'servico'
      { parent_code: @item.parent&.code, category_codes: codes(@item.categories),
        default_category_code: @item.default_category&.code }
    when 'justificativa'
      { status_codes: codes(@item.ticket_statuses) }
    else
      {}
    end
  end

  def codes(records)
    records.filter_map(&:code).sort
  end
end
