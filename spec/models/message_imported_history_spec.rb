require 'rails_helper'

# Regressão B36 (auditoria 18/11): copiar mensagens para um ticket (Criar ticket interno / Incluir
# em ticket existente) cria mensagens de saída não privadas; numa conversa de WhatsApp ou e-mail o
# send_reply as reenviava ao cliente. Histórico copiado nunca vai ao canal.
RSpec.describe Message do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:inbox) { create(:inbox, account: account, channel: channel) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:agent) { create(:user, account: account) }

  def outgoing(attrs = {})
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: agent, **attrs)
  end

  it 'mensagem copiada como histórico não é enviada ao canal do cliente' do
    expect { outgoing(content_attributes: { imported_ticket_history: true, imported_role: 'agent' }) }
      .not_to have_enqueued_job(SendReplyJob)
  end

  it 'resposta normal do agente continua sendo enviada' do
    expect { outgoing }.to have_enqueued_job(SendReplyJob)
  end
end
