module Current
  thread_mattr_accessor :user
  # Fork (Portal do Cliente): agente em nome de quem a integração age (cabeçalho
  # X-Portal-Acting-Agent, só de chave de administrador). Só troca o nome nas
  # atividades da conversa; permissão continua sendo a do dono da chave.
  thread_mattr_accessor :acting_user
  thread_mattr_accessor :account
  thread_mattr_accessor :account_user
  thread_mattr_accessor :executed_by
  thread_mattr_accessor :contact
  thread_mattr_accessor :inbox

  def self.reset
    Current.user = nil
    Current.acting_user = nil
    Current.account = nil
    Current.account_user = nil
    Current.executed_by = nil
    Current.contact = nil
    Current.inbox = nil
  end
end
