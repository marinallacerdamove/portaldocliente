# PATCH LOCAL (fork) - código de negócio de um item do cadastro sincronizado com
# o Portal do Cliente (SRV-0042, REG-0007...). Nasce nulo; vai de nulo para um
# valor uma única vez e nunca mais muda. NÃO entra por atribuição em massa nem
# pela API de admin (`code=` é privado): o único caminho é `assign_code`, usado
# pelo endpoint de sincronização com o Portal.
module TicketCatalogCode
  extend ActiveSupport::Concern

  CODE_FORMAT = /\A[A-Z0-9]+(-[A-Z0-9]+)*\z/
  CODE_MAX_LENGTH = 32

  included do
    validates :code, format: { with: CODE_FORMAT }, length: { maximum: CODE_MAX_LENGTH },
                     uniqueness: { scope: :account_id }, allow_nil: true, if: :will_save_change_to_code?
    validate :code_never_changes

    before_validation { self.code = code.to_s.strip.presence }
  end

  # Caminho do endpoint de sincronização: grava o código (nulo -> valor) sem
  # abrir `code=` pra atribuição em massa. A validação recusa trocar um código
  # que já existe.
  def assign_code(value)
    self.code = value
  end

  private

  def code=(value)
    self[:code] = value
  end

  def code_never_changes
    return unless persisted? && will_save_change_to_code? && code_in_database.present?

    errors.add(:code, :immutable, message: 'cannot be changed once set')
  end
end
