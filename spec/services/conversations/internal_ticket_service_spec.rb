require 'rails_helper'

RSpec.describe Conversations::InternalTicketService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:team) { create(:team, account: account) }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    create(:team_member, team: team, user: agent)
  end

  def create_ticket(params)
    described_class.new(inbox: inbox, contact: contact, user: agent, params: params).perform
  end

  it 'creates the ticket with everything the form sets' do
    ticket = create_ticket(
      team: team, assignee: agent, priority: 'high',
      custom_attributes: { 'assunto' => 'Erro na nota', 'campos_adicionais' => { 'liberacoes' => 'Sim' } },
      message: { content: 'Descrição', private: true }, watcher_ids: [agent.id]
    )

    expect(ticket).to have_attributes(inbox: inbox, contact: contact, team: team, assignee: agent, priority: 'high')
    expect(ticket.custom_attributes).to include('assunto' => 'Erro na nota', 'campos_adicionais' => { 'liberacoes' => 'Sim' })
    expect(ticket.messages.where(private: true).pick(:content)).to eq('Descrição')
    expect(ticket.conversation_participants.pluck(:user_id)).to eq([agent.id])
  end

  it 'keeps the chosen assignee even when he is not in the chosen team (the team follows him, as when assigning on screen)' do
    ticket = create_ticket(team: create(:team, account: account), assignee: agent)

    expect(ticket).to have_attributes(team: team, assignee: agent)
  end

  it 'renders the protocol in the first message' do
    ticket = create_ticket(message: { content: 'Protocolo #{{conversation.display_id}}', private: true })

    expect(ticket.messages.where(private: true).pick(:content)).to eq("Protocolo ##{ticket.display_id}")
  end

  it 'copies the selected messages from another conversation' do
    source = create(:conversation, account: account)
    copied = create(:message, conversation: source, account: account, content: 'Mensagem original')

    ticket = create_ticket(copy: { source: source, message_ids: [copied.id] })

    expect(ticket.messages.pluck(:content)).to include('Mensagem original')
  end

  it 'links the new ticket as child and announces it in the related conversation' do
    related = create(:conversation, account: account)

    ticket = create_ticket(team: team, link: { conversation: related, relation: 'child', announce: true })

    expect(ticket.custom_attributes['ticket_pai_id']).to eq(related.display_id.to_s)
    expect(related.reload.custom_attributes['ticket_filhos_ids']).to eq(ticket.display_id.to_s)
    expect(related.messages.where(private: true).last.content).to start_with("Ticket filho criado para o time #{team.name}: ")
  end

  it 'links the new ticket as parent' do
    related = create(:conversation, account: account)

    ticket = create_ticket(link: { conversation: related, relation: 'parent' })

    expect(related.reload.custom_attributes['ticket_pai_id']).to eq(ticket.display_id.to_s)
    expect(ticket.reload.custom_attributes['ticket_filhos_ids']).to eq(related.display_id.to_s)
  end

  it 'creates nothing when a step fails' do
    source = create(:conversation, account: create(:account))

    expect do
      create_ticket(message: { content: 'Descrição' }, copy: { source: source, message_ids: [1] })
    end.to raise_error(ArgumentError).and(not_change(Conversation, :count)).and(not_change(Message, :count))
  end

  it 'refuses an unknown priority before creating anything' do
    expect { create_ticket(priority: 'whatever') }.to raise_error(described_class::InvalidTicket, 'priority')
  end

  it 'refuses watchers who cannot see the inbox' do
    outsider = create(:user, account: account, role: :agent)

    expect { create_ticket(watcher_ids: [outsider.id]) }.to raise_error(described_class::InvalidTicket, 'watchers')
  end
end
