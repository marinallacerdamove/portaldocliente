# PATCH LOCAL (fork) - campo adicional do ticket (Movidesk: Campos adicionais).
# Só aparece na conversa quando alguma regra de exibição ativa o inclui
# (TicketFieldRule). A chave é gerada do nome na criação e não muda depois,
# pra renomear sem perder os valores já gravados nas conversas; o Portal gera
# a mesma chave do mesmo nome, é por ela que os valores sincronizam.
class TicketCustomField < ApplicationRecord
  FIELD_TYPES = %w[text textarea list single_select multi_select date datetime].freeze
  OPTION_TYPES = %w[list single_select multi_select].freeze
  KEY_MAX_LENGTH = 60

  belongs_to :account

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :key, presence: true, uniqueness: { scope: :account_id }
  validates :field_type, inclusion: { in: FIELD_TYPES }
  validate :options_for_option_types

  before_validation :normalize
  before_validation :assign_key, on: :create

  # Mesmo algoritmo do Portal (TicketCustomField.key_for), a chave precisa sair igual.
  def self.key_for(name)
    slug = ActiveSupport::Inflector.transliterate(name.to_s).downcase.gsub(/[^a-z0-9]+/, '_')
    slug.first(KEY_MAX_LENGTH).gsub(/\A_+|_+\z/, '').presence || 'campo'
  end

  def as_json(*)
    slice(:id, :name, :key, :field_type, :hint, :options, :active, :position)
  end

  private

  def normalize
    self.name = name.to_s.squish
    self.hint = hint.to_s.squish.presence
    self.options = OPTION_TYPES.include?(field_type) ? Array(options).map { |option| option.to_s.squish }.compact_blank.uniq : []
  end

  def assign_key
    return if key.present?

    base = self.class.key_for(name)
    taken = self.class.where(account_id: account_id).where('key = ? OR key LIKE ?', base, "#{base}\\_%").pluck(:key)
    self.key = base
    suffix = 1
    self.key = "#{base}_#{suffix += 1}" while taken.include?(key)
  end

  def options_for_option_types
    errors.add(:options, :blank) if OPTION_TYPES.include?(field_type) && options.empty?
  end
end
