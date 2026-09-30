# == Schema Information
#
# Table name: companies
#
#  additional_attributes :jsonb
#  custom_attributes     :jsonb
#  last_activity_at      :datetime
#  id             :bigint           not null, primary key
#  contacts_count :integer
#  description    :text
#  domain         :string
#  name           :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#
# Indexes
#
#  index_companies_on_account_and_domain   (account_id,domain) UNIQUE WHERE (domain IS NOT NULL)
#  index_companies_on_account_id           (account_id)
#  index_companies_on_name_and_account_id  (name,account_id)
#
class Company < ApplicationRecord
  include Avatarable

  ACTIVITY_ROLLUP_INTERVAL = 5.minutes

  validates :account_id, presence: true
  validates :name, presence: true, length: { maximum: Limits::COMPANY_NAME_LENGTH_LIMIT }
  validates :domain, allow_blank: true, format: {
    with: /\A[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+\z/,
    message: I18n.t('errors.companies.domain.invalid')
  }
  validates :domain, uniqueness: { scope: :account_id }, if: -> { domain.present? }
  validates :description, length: { maximum: Limits::COMPANY_DESCRIPTION_LENGTH_LIMIT }
  validates :custom_attributes, jsonb_attributes_length: true

  belongs_to :account
  has_many :contacts, dependent: :nullify
  before_validation :prepare_jsonb_attributes
  after_create_commit :fetch_favicon, if: -> { domain.present? }
  after_update_commit :enqueue_contact_company_name_sync, if: :saved_change_to_name?

  # PATCH LOCAL (fork) - sincronização de empresas com o Portal do Cliente.
  # CPF/CNPJ (custom_attributes.cnpj) é a chave que liga uma empresa daqui a
  # uma do Portal, por isso não pode repetir dentro da mesma conta.
  validate :cnpj_unique_in_account
  after_create_commit :dispatch_create_event
  after_update_commit :dispatch_update_event, if: :portal_synced_attributes_changed?
  after_commit :sync_empresa_list_attribute, if: :empresa_list_affected?

  # Só o que o Portal espelha - last_activity_at/contacts_count mudam a cada
  # mensagem de contato e não podem virar webhook.
  PORTAL_SYNCED_ATTRIBUTES = %w[name custom_attributes].freeze
  CNPJ_KEY_SQL = "upper(regexp_replace(companies.custom_attributes->>'cnpj', '[^0-9A-Za-z]', '', 'g'))".freeze

  scope :ordered_by_name, -> { order(:name) }
  scope :search_by_name_or_domain, lambda { |query|
    term = query.strip
    by_name = where('name ILIKE :search OR domain ILIKE :search', search: "%#{term}%")
    key = Company.cnpj_key(term)
    next by_name unless key.match?(/\d/)

    by_name.or(where("#{CNPJ_KEY_SQL} LIKE :key", key: "%#{key}%"))
  }
  scope :with_cnpj_key, ->(key) { where("#{CNPJ_KEY_SQL} = ?", key) }

  # CNPJ alfanumérico (reforma tributária) usa letras também - por isso não
  # é só "tirar tudo que não é dígito".
  def self.cnpj_key(value)
    value.to_s.gsub(/[^0-9A-Za-z]/, '').upcase
  end

  # Lista do atributo de conversa "empresa" (dropdown em Ações da conversa)
  # é sempre derivada das empresas da conta - nunca editada à mão, senão
  # volta a divergir do cadastro.
  def self.sync_empresa_list_attribute!(account)
    definition = account.custom_attribute_definitions.conversation_attribute.find_by(attribute_key: 'empresa')
    return unless definition

    names = account.companies.order(:name).pluck(:name).map(&:strip).uniq
    definition.update!(attribute_values: names) unless definition.attribute_values == names
  end

  def webhook_data
    {
      account: account.webhook_data,
      id: id,
      name: name,
      domain: domain,
      description: description,
      custom_attributes: custom_attributes
    }
  end

  scope :order_on_contacts_count, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order("\"companies\".\"contacts_count\" #{direction} NULLS LAST")
      )
    )
  }
  scope :order_on_last_activity_at, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order("\"companies\".\"last_activity_at\" #{direction} NULLS LAST")
      )
    )
  }

  def record_activity_at!(activity_at)
    return if last_activity_at.present? && last_activity_at > activity_at - ACTIVITY_ROLLUP_INTERVAL

    update!(last_activity_at: activity_at)
  end

  private

  def prepare_jsonb_attributes
    self.additional_attributes = {} unless additional_attributes.is_a?(Hash)
    self.custom_attributes = {} unless custom_attributes.is_a?(Hash)
  end

  def fetch_favicon
    Avatar::AvatarFromFaviconJob.set(wait: 5.seconds).perform_later(self)
  end

  def enqueue_contact_company_name_sync
    Companies::SyncContactNamesJob.perform_later(company_id: id)
  end

  def cnpj_unique_in_account
    key = Company.cnpj_key(custom_attributes&.dig('cnpj'))
    return if key.blank?

    existing = account.companies.where.not(id: id).with_cnpj_key(key).first
    errors.add(:base, I18n.t('errors.companies.cnpj.taken', name: existing.name)) if existing
  end

  def dispatch_create_event
    Rails.configuration.dispatcher.dispatch(COMPANY_CREATED, Time.zone.now, company: self)
  end

  def dispatch_update_event
    Rails.configuration.dispatcher.dispatch(COMPANY_UPDATED, Time.zone.now, company: self, changed_attributes: previous_changes)
  end

  def portal_synced_attributes_changed?
    previous_changes.keys.intersect?(PORTAL_SYNCED_ATTRIBUTES)
  end

  def empresa_list_affected?
    destroyed? || previous_changes.key?('id') || previous_changes.key?('name')
  end

  def sync_empresa_list_attribute
    Company.sync_empresa_list_attribute!(account)
  end
end
