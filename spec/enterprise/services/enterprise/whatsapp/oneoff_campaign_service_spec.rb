require 'rails_helper'

# PATCH LOCAL (fork) - destinatários da campanha (Enterprise) com Grupos do Portal como público.
describe Whatsapp::OneoffCampaignService do
  let(:account) { create(:account) }
  let!(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
  end
  let(:label) { create(:label, account: account) }
  let(:template_params) do
    {
      'name' => 'ticket_status_updated', 'namespace' => '23423423_2342423_324234234_2343224', 'category' => 'UTILITY',
      'language' => 'en', 'processed_params' => { 'body' => { 'name' => 'John', 'ticket_id' => '2332' } }
    }
  end
  let(:campaign) do
    create(:campaign, inbox: whatsapp_channel.inbox, account: account, template_params: template_params,
                      audience: [{ type: 'Label', id: label.id }, { type: 'PortalGroup', id: '7' }])
  end
  let(:label_contact) { create(:contact, :with_phone_number, account: account) }
  let(:group_contact) { create(:contact, :with_phone_number, account: account) }
  let(:portal_group_url) { 'http://portal.test/api/internal/client_groups/7/recipients' }

  around do |example|
    with_modified_env(PORTAL_INTERNAL_API_URL: 'http://portal.test', PORTAL_INTERNAL_API_TOKEN: 'segredo') { example.run }
  end

  before do
    account.enable_features!(:whatsapp_campaign)
    label_contact.update_labels([label.title])
    allow(whatsapp_channel).to receive(:send_template).and_return('wamid.1', 'wamid.2')
    allow_any_instance_of(described_class).to receive(:channel).and_return(whatsapp_channel) # rubocop:disable RSpec/AnyInstance
  end

  it 'creates one recipient per contact of the labels and of the Portal group, without repeating' do
    stub_request(:get, portal_group_url)
      .to_return(status: 200, body: { data: [{ chatwoot_contact_id: group_contact.id }, { chatwoot_contact_id: label_contact.id }] }.to_json)

    described_class.new(campaign: campaign).perform

    expect(campaign.campaign_recipients.pluck(:contact_id)).to contain_exactly(label_contact.id, group_contact.id)
    expect(campaign.reload.completed?).to be true
  end

  it 'creates no recipient and sends nothing when the Portal is down' do
    stub_request(:get, portal_group_url).to_raise(Errno::ECONNREFUSED)

    expect(whatsapp_channel).not_to receive(:send_template)
    expect { described_class.new(campaign: campaign).perform }.to raise_error(PortalGroups::Client::Error)

    expect(campaign.campaign_recipients.count).to eq(0)
    expect(campaign.reload.completed?).to be false
  end

  it 'leaves out a group the Portal refuses (inactivated or gone) and sends to the rest, without retrying' do
    stub_request(:get, portal_group_url).to_return(status: 404, body: { error: 'Grupo não encontrado.' }.to_json)

    described_class.new(campaign: campaign).perform

    expect(campaign.campaign_recipients.pluck(:contact_id)).to contain_exactly(label_contact.id)
    expect(campaign.reload.completed?).to be true
  end

  it 'puts the campaign back to active on any network failure, not only connection refused' do
    campaign.update!(scheduled_at: 1.minute.ago)
    stub_request(:get, portal_group_url).to_raise(Errno::EHOSTUNREACH)

    expect { campaign.trigger! }.to raise_error(PortalGroups::Client::Error)
    expect(campaign.reload).to have_attributes(campaign_status: 'active', started_at: nil)
  end

  it 'puts the campaign back to active when the Portal is down, so the scheduler tries again' do
    campaign.update!(scheduled_at: 1.minute.ago)
    stub_request(:get, portal_group_url).to_raise(Errno::ECONNREFUSED)

    expect { campaign.trigger! }.to raise_error(PortalGroups::Client::Error)
    expect(campaign.reload).to have_attributes(campaign_status: 'active', started_at: nil)

    stub_request(:get, portal_group_url).to_return(status: 200, body: { data: [{ chatwoot_contact_id: group_contact.id }] }.to_json)
    campaign.trigger!
    expect(campaign.reload.completed?).to be true
    expect(campaign.campaign_recipients.pluck(:contact_id)).to contain_exactly(label_contact.id, group_contact.id)
  end
end
