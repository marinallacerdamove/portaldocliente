require 'rails_helper'

RSpec.describe TicketCatalogRename do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:field) { account.ticket_custom_fields.create!(name: 'Causa', field_type: 'text') }

  def service_rule(account, attribute, value, field = self.field)
    account.ticket_field_rules.create!(name: "Regra #{attribute}",
                                       conditions: [{ group: 'all', attribute: attribute, operator: 'equal_to', value: value }],
                                       fields: [{ field_id: field.id }])
  end

  def set_attribute_action(key, value) = { 'action_name' => 'set_custom_attribute', 'action_params' => [key, value] }

  describe 'job enqueueing' do
    it 'enqueues the conversation rename with the old value when the name changes' do
      status = account.ticket_statuses.create!(name: 'Parado', base: 'parado')

      expect { status.update!(name: 'Aguardando') }
        .to have_enqueued_job(TicketCatalog::RenameConversationsJob).with(account.id, 'TicketStatus', [[status.id, 'Parado']])
    end

    it 'does nothing when only other fields change' do
      status = account.ticket_statuses.create!(name: 'Parado', base: 'parado')

      expect { status.update!(active: false) }.not_to have_enqueued_job(TicketCatalog::RenameConversationsJob)
    end

    it 'does not enqueue on create' do
      expect { account.ticket_close_reasons.create!(name: 'Duplicado') }.not_to have_enqueued_job(TicketCatalog::RenameConversationsJob)
    end

    it 'enqueues nothing when the save is rolled back' do
      reason = account.ticket_close_reasons.create!(name: 'Duplicado')

      expect do
        ActiveRecord::Base.transaction do
          reason.update!(name: 'Duplicidade')
          raise ActiveRecord::Rollback
        end
      end.not_to have_enqueued_job(TicketCatalog::RenameConversationsJob)
    end
  end

  describe 'rules, macros and automations' do
    let(:service) { account.ticket_services.create!(name: 'Fiscal') }
    let(:category) { account.ticket_categories.create!(name: 'Dúvida') }

    before do
      service
      category
    end

    it 'swaps the exact old value in field rule conditions of the same attribute only' do
      rule = service_rule(account, 'servico', 'Fiscal')
      other_attribute = service_rule(account, 'tipo_de_solicitacao', 'Fiscal')
      other_value = service_rule(account, 'servico', 'Fiscal Antigo')
      foreign = service_rule(other_account, 'servico', 'Fiscal', other_account.ticket_custom_fields.create!(name: 'Causa', field_type: 'text'))

      service.update!(name: 'Fiscal e Contábil')

      expect(rule.reload.conditions.first['value']).to eq('Fiscal e Contábil')
      expect(other_attribute.reload.conditions.first['value']).to eq('Fiscal')
      expect(other_value.reload.conditions.first['value']).to eq('Fiscal Antigo')
      expect(foreign.reload.conditions.first['value']).to eq('Fiscal')
    end

    it 'swaps the status name in "status" conditions' do
      status = account.ticket_statuses.create!(name: 'Parado', base: 'parado')
      rule = service_rule(account, 'status', 'Parado')

      status.update!(name: 'Aguardando')

      expect(rule.reload.conditions.first['value']).to eq('Aguardando')
    end

    it 'swaps the value of set_custom_attribute actions in macros, keeping the other actions' do
      macro = create(:macro, account: account, name: 'Fiscal NF',
                             actions: [set_attribute_action('servico', 'Fiscal'), set_attribute_action('tipo_de_solicitao', 'Fiscal'),
                                       { 'action_name' => 'add_label', 'action_params' => ['Fiscal'] }])

      service.update!(name: 'Fiscal e Contábil')

      expect(macro.reload.actions).to eq([set_attribute_action('servico', 'Fiscal e Contábil'),
                                          set_attribute_action('tipo_de_solicitao', 'Fiscal'),
                                          { 'action_name' => 'add_label', 'action_params' => ['Fiscal'] }])
    end

    it 'swaps conditions and actions of automation rules, without running automation callbacks' do
      rule = create(:automation_rule, account: account,
                                      conditions: [{ 'attribute_key' => 'tipo_de_solicitao', 'filter_operator' => 'equal_to',
                                                     'values' => %w[Dúvida Outra], 'query_operator' => nil }],
                                      actions: [set_attribute_action('tipo_de_solicitao', 'Dúvida')])

      category.update!(name: 'Dúvida técnica')

      expect(rule.reload.conditions.first['values']).to eq(['Dúvida técnica', 'Outra'])
      expect(rule.actions).to eq([set_attribute_action('tipo_de_solicitao', 'Dúvida técnica')])
    end

    it 'does not touch macros of other accounts' do
      foreign = create(:macro, account: other_account, actions: [set_attribute_action('servico', 'Fiscal')])

      service.update!(name: 'Fiscal e Contábil')

      expect(foreign.reload.actions).to eq([set_attribute_action('servico', 'Fiscal')])
    end

    it 'rolls the swap back together with the rename' do
      rule = service_rule(account, 'servico', 'Fiscal')

      ActiveRecord::Base.transaction do
        service.update!(name: 'Fiscal e Contábil')
        raise ActiveRecord::Rollback
      end

      expect(rule.reload.conditions.first['value']).to eq('Fiscal')
    end
  end

  describe 'service tree' do
    let!(:root) { account.ticket_services.create!(name: 'Fiscal') }
    let!(:child) { account.ticket_services.create!(name: 'NF-e', parent: root) }
    let!(:grandchild) { account.ticket_services.create!(name: 'Cancelamento', parent: child) }
    let(:macro) { create(:macro, account: account, actions: [set_attribute_action('servico', 'Fiscal › NF-e › Cancelamento')]) }
    let(:rule) { service_rule(account, 'servico', 'Fiscal › NF-e') }

    it 'renames the whole subtree when a parent is renamed' do
      macro
      rule

      expect { root.update!(name: 'Tributário') }
        .to have_enqueued_job(TicketCatalog::RenameConversationsJob)
        .with(account.id, 'TicketService', [[root.id, 'Fiscal'], [child.id, 'Fiscal › NF-e'], [grandchild.id, 'Fiscal › NF-e › Cancelamento']])
      expect(macro.reload.actions).to eq([set_attribute_action('servico', 'Tributário › NF-e › Cancelamento')])
      expect(rule.reload.conditions.first['value']).to eq('Tributário › NF-e')
    end

    it 'renames only the item and its descendants when a middle node is renamed' do
      expect { child.update!(name: 'NF-e 4.0') }
        .to have_enqueued_job(TicketCatalog::RenameConversationsJob)
        .with(account.id, 'TicketService', [[child.id, 'Fiscal › NF-e'], [grandchild.id, 'Fiscal › NF-e › Cancelamento']])
    end

    it 'treats a move to another parent as a rename of the subtree' do
      other = account.ticket_services.create!(name: 'Contábil')
      macro

      expect { child.update!(parent: other) }
        .to have_enqueued_job(TicketCatalog::RenameConversationsJob)
        .with(account.id, 'TicketService', [[child.id, 'Fiscal › NF-e'], [grandchild.id, 'Fiscal › NF-e › Cancelamento']])
      expect(macro.reload.actions).to eq([set_attribute_action('servico', 'Contábil › NF-e › Cancelamento')])
    end

    it 'does not rename when the move leaves the path unchanged' do
      expect { root.update!(position: 3) }.not_to have_enqueued_job(TicketCatalog::RenameConversationsJob)
    end
  end
end
