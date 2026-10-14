# PATCH LOCAL (fork) - grava nas conversas existentes o código (servico_codigo...)
# dos itens do cadastro que já têm código, casando pelo nome atual do item.
# Passo da ativação por conta do cadastro por código; ver
# `rake ticket_catalog:backfill_conversation_codes`.
#
# SQL direto em lotes de ids (BETWEEN) e uma instrução por lote e por cadastro:
# sem callback, sem webhook, sem mexer em updated_at. Repetir é seguro (só grava
# onde o código ainda difere). Sem `apply` só conta o que seria gravado.
# Ao final relata, por chave, as conversas cujo nome não existe em nenhum item
# do cadastro (órfãs de renomes antigos): ficam sem código.
class TicketCatalog::BackfillConversationCodes
  BATCH_SIZE = 5000
  ORPHAN_SAMPLE = 10

  def initialize(account_id, apply: false, output: $stdout)
    @account = Account.find(account_id)
    @apply = apply
    @output = output
  end

  def call
    @output.puts "ticket_catalog:backfill_conversation_codes account=#{@account.id} mode=#{@apply ? 'APPLY' : 'dry run'}"
    TicketCatalogCodes::CATALOG_ASSOCIATIONS.map { |key, association| backfill(key, @account.public_send(association)) }
  end

  private

  def backfill(key, scope)
    items = scope.to_a
    pairs = items.select(&:code).map { |item| [item.attribute_value, item.code] }
    updated = pairs.empty? ? 0 : write(key, pairs)
    orphans = orphans_of(key, items.map(&:attribute_value))
    @output.puts report_line(key, items.size, pairs.size, updated, orphans)
    { key: key, items_with_code: pairs.size, updated: updated, orphans: orphans }
  end

  def report_line(key, items_count, coded_count, updated, orphans)
    sample = orphans.first(ORPHAN_SAMPLE).map { |name, count| "\n      #{count}x #{name.inspect}" }.join
    "  #{key}: #{coded_count} item(s) with code, #{updated} conversation(s) #{@apply ? 'updated' : 'would be updated'}, " \
      "#{items_count - coded_count} item(s) still without code, #{orphans.sum(&:last)} conversation(s) with orphan name " \
      "(#{orphans.size} distinct)#{sample}"
  end

  def write(key, pairs)
    code_key = TicketContract::CODE_KEYS.fetch(key)
    values = pairs.map { |name, code| ActiveRecord::Base.sanitize_sql_array(['(?, ?)', name, code]) }.join(', ')
    return count_pending(key, code_key, values) unless @apply

    id_ranges.sum do |low, high|
      ActiveRecord::Base.connection.update(sanitize(<<~SQL.squish, code_key, @account.id, low, high, key, code_key))
        UPDATE conversations c SET custom_attributes = c.custom_attributes || jsonb_build_object(?::text, v.code)
        FROM (VALUES #{values}) AS v(name, code)
        WHERE c.account_id = ? AND c.id BETWEEN ? AND ? AND c.custom_attributes ->> ? = v.name
        AND c.custom_attributes ->> ? IS DISTINCT FROM v.code
      SQL
    end
  end

  def count_pending(key, code_key, values)
    ActiveRecord::Base.connection.select_value(sanitize(<<~SQL.squish, @account.id, key, code_key)).to_i
      SELECT count(*) FROM conversations c, (VALUES #{values}) AS v(name, code)
      WHERE c.account_id = ? AND c.custom_attributes ->> ? = v.name AND c.custom_attributes ->> ? IS DISTINCT FROM v.code
    SQL
  end

  def orphans_of(key, known_values)
    known = known_values.presence || ['']
    conversations.where("custom_attributes ->> ? <> ''", key).where.not('custom_attributes ->> ? = ANY (ARRAY[?]::text[])', key, known)
                 .group("custom_attributes ->> #{ActiveRecord::Base.connection.quote(key)}").order(Arel.sql('count(*) DESC'))
                 .count.to_a
  end

  def id_ranges
    low, high = conversations.pick(Arel.sql('MIN(id)'), Arel.sql('MAX(id)'))
    return [] unless low

    (low..high).step(BATCH_SIZE).map { |start| [start, start + BATCH_SIZE - 1] }
  end

  def conversations
    Conversation.where(account_id: @account.id)
  end

  def sanitize(sql, *binds)
    ActiveRecord::Base.sanitize_sql_array([sql, *binds])
  end
end
