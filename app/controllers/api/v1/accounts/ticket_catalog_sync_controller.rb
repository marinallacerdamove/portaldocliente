# PATCH LOCAL (fork) - escrita do cadastro de atendimento pelo Portal do
# Cliente, dono do cadastro (PUT idempotente por código). Acha o item por
# código; senão pelo id que o Portal já conhece (item criado aqui antes de
# receber código); senão pelo nome ainda sem código; senão cria. O código só
# entra por aqui (assign_code). O save marca `portal_sync` para não devolver o
# webhook ao Portal.
class Api::V1::Accounts::TicketCatalogSyncController < Api::V1::Accounts::BaseController
  class UnknownCode < StandardError; end

  # Colunas que chegam como lista.
  LIST_COLUMNS = %w[allowed_priorities options].freeze

  rescue_from UnknownCode do |error|
    render json: { error: error.message }, status: :unprocessable_entity
  end

  before_action :check_authorization

  def upsert
    @record = find_or_build_record
    @record.portal_sync = true
    ActiveRecord::Base.transaction do
      @record.assign_attributes(record_attributes)
      @record.assign_code(params.require(:code))
      assign_references
      @record.save!
    end
    render json: { id: @record.id, code: @record.code, updated_at: @record.updated_at.iso8601(6) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: (e.record.errors.of_kind?(:name, :taken) ? :conflict : :unprocessable_entity)
  end

  private

  def key
    params[:catalog]
  end

  def catalog_model
    TicketCatalog::SyncFields::CATALOGS.dig(key, :model).constantize
  end

  def scope
    Current.account.public_send(TicketCatalog::SyncFields::CATALOGS.dig(key, :association))
  end

  def parent
    return unless key == 'servico' && params[:parent_code].present?

    @parent ||= find_by_code!(scope, params[:parent_code])
  end

  def find_or_build_record
    parent # pai desconhecido recusa antes de qualquer busca
    scope.find_by(code: params[:code]) ||
      scope.find_by(id: params[:remote_id], code: nil) ||
      unclaimed_by_name ||
      scope.new
  end

  # Regra repete nome: só adota quando há uma única sem código com esse nome
  # (as que já existiam nos dois lados são ligadas antes pelo rake do Portal).
  def unclaimed_by_name
    candidates = scope.where(code: nil).where('lower(name) = lower(?)', params[:name].to_s.squish)
    candidates = candidates.where(parent_id: parent&.id) if key == 'servico'
    return candidates.first unless key == 'regra'

    candidates.first if candidates.one?
  end

  def record_attributes
    params.permit(*TicketCatalog::SyncFields::COLUMNS.fetch(key).map { |field| LIST_COLUMNS.include?(field) ? { field => [] } : field })
  end

  def assign_references
    @record.parent = parent if key == 'servico' && params.key?(:parent_code)
    assign_default_category
    assign_list(:categories, :ticket_categories, 'category_codes') if key == 'servico'
    assign_list(:ticket_statuses, :ticket_statuses, 'status_codes') if key == 'justificativa'
    assign_rule_fields if key == 'regra'
  end

  # Campo citado pela regra que esta conta ainda não tem: 422, o Portal repete
  # depois que o campo chegar.
  def assign_rule_fields
    %w[conditions fields].each do |attribute|
      next unless params.key?(attribute)

      entries, missing = TicketCatalog::SyncFields.rule_from_wire(params.to_unsafe_h[attribute], Current.account)
      raise UnknownCode, "unknown field_key: #{missing.join(', ')}" if missing.any?

      @record.public_send("#{attribute}=", entries)
    end
  end

  def assign_default_category
    return unless key == 'servico' && params.key?(:default_category_code)

    code = params[:default_category_code]
    @record.default_category = code.present? ? find_by_code!(Current.account.ticket_categories, code) : nil
  end

  def assign_list(association, source, param)
    return unless params.key?(param)

    codes = Array(params[param]).compact_blank
    records = Current.account.public_send(source).where(code: codes).to_a
    missing = codes - records.map(&:code)
    raise UnknownCode, "unknown #{param}: #{missing.join(', ')}" if missing.any?

    @record.replace_synced_association(association, records, param)
  end

  def find_by_code!(relation, code)
    relation.find_by(code: code) || raise(UnknownCode, "unknown code: #{code}")
  end

  def check_authorization
    authorize(catalog_model, :update?)
  end
end
