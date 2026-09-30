require 'rails_helper'

RSpec.describe ConversationPreviewPreloader do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  describe '.preload' do
    it 'returns an empty hash for an empty collection' do
      expect(described_class.preload([])).to eq({})
    end

    it 'returns nil last_message/last_non_activity_message for a conversation without messages' do
      result = described_class.preload([conversation])

      entry = result[conversation.id]
      expect(entry.last_message).to be_nil
      expect(entry.last_non_activity_message).to be_nil
    end

    it 'picks the most recently created message as last_message, regardless of type' do
      travel_to(2.minutes.ago) { create(:message, conversation: conversation, account: account, message_type: :incoming) }
      latest_activity = travel_to(1.minute.ago) { create(:message, conversation: conversation, account: account, message_type: :activity) }

      entry = described_class.preload([conversation])[conversation.id]

      expect(entry.last_message.id).to eq(latest_activity.id)
    end

    it 'picks the most recently created non-activity message as last_non_activity_message, skipping activity messages' do
      latest_real = travel_to(2.minutes.ago) { create(:message, conversation: conversation, account: account, message_type: :incoming) }
      travel_to(1.minute.ago) { create(:message, conversation: conversation, account: account, message_type: :activity) }

      entry = described_class.preload([conversation])[conversation.id]

      expect(entry.last_non_activity_message.id).to eq(latest_real.id)
    end

    it 'does not mix up messages between different conversations' do
      other_conversation = create(:conversation, account: account)
      message_a = create(:message, conversation: conversation, account: account)
      message_b = create(:message, conversation: other_conversation, account: account)

      result = described_class.preload([conversation, other_conversation])

      expect(result[conversation.id].last_message.id).to eq(message_a.id)
      expect(result[other_conversation.id].last_message.id).to eq(message_b.id)
    end

    it 'preloads attachments on the returned messages without extra queries' do
      message = create(:message, :with_attachment, conversation: conversation, account: account)

      entry = described_class.preload([conversation])[conversation.id]

      queries = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _started, _finished, _unique_id, event|
        queries << event[:sql] unless event[:cached]
      end
      begin
        entry.last_message.attachments.to_a
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      expect(queries).to be_empty
      expect(entry.last_message.id).to eq(message.id)
      expect(entry.last_message.attachments.first.id).to eq(message.attachments.first.id)
    end

    it "points the resolved message's conversation back at the same preloaded conversation object" do
      create(:message, conversation: conversation, account: account)

      entry = described_class.preload([conversation])[conversation.id]

      expect(entry.last_message.association(:conversation).target).to equal(conversation)
    end
  end
end
