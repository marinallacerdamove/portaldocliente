require 'rails_helper'

RSpec.describe MessageContentPresenter do
  let(:conversation) { create(:conversation) }
  let(:message) { create(:message, conversation: conversation, content_type: content_type, content: content) }
  let(:presenter) { described_class.new(message) }

  describe '#outgoing_content' do
    # PATCH LOCAL (fork) - mensagem de agente sai pelos canais com o nome dele na frente.
    context 'with the agent name prefix' do
      let(:whatsapp_channel) { create(:channel_whatsapp, sync_templates: false, validate_provider_config: false) }
      let(:whatsapp_conversation) { create(:conversation, inbox: whatsapp_channel.inbox) }
      let(:agent) { create(:user, account: whatsapp_conversation.account, name: 'Ana Agente') }

      def outgoing(conversation:, sender:, content: 'Olá')
        described_class.new(create(:message, conversation: conversation, message_type: :outgoing, sender: sender, content: content))
                       .outgoing_content
      end

      it 'prefixes the agent name on a customer channel (WhatsApp)' do
        expect(outgoing(conversation: whatsapp_conversation, sender: agent)).to eq('*Ana Agente*: Olá')
      end

      it 'does not prefix bot or contact messages' do
        expect(outgoing(conversation: whatsapp_conversation, sender: create(:agent_bot))).to eq('Olá')
        expect(outgoing(conversation: whatsapp_conversation, sender: create(:contact, account: whatsapp_conversation.account))).to eq('Olá')
      end

      it 'does not prefix on API channels (Portal do Cliente gets the message as is)' do
        api_conversation = create(:conversation, inbox: create(:channel_api).inbox)
        api_agent = create(:user, account: api_conversation.account)
        expect(outgoing(conversation: api_conversation, sender: api_agent)).not_to include(api_agent.name)
      end
    end

    context 'when message is not input_csat' do
      let(:content_type) { 'text' }
      let(:content) { 'Regular message' }

      it 'returns content transformed for channel (HTML for WebWidget)' do
        expect(presenter.outgoing_content).to eq("<p>Regular message</p>\n")
      end
    end

    context 'when message is input_csat and inbox is web widget' do
      let(:content_type) { 'input_csat' }
      let(:content) { 'Rate your experience' }

      before do
        allow(message.inbox).to receive(:web_widget?).and_return(true)
      end

      it 'returns content without survey URL (HTML for WebWidget)' do
        expect(presenter.outgoing_content).to eq("<p>Rate your experience</p>\n")
      end
    end

    context 'when message is input_csat and inbox is not web widget' do
      let(:content_type) { 'input_csat' }
      let(:content) { 'Rate your experience' }

      before do
        allow(message.inbox).to receive(:web_widget?).and_return(false)
      end

      it 'returns I18n default message when no CSAT config and dynamically generates survey URL (HTML format)' do
        with_modified_env 'FRONTEND_URL' => 'https://app.chatwoot.com' do
          expected_url = "https://app.chatwoot.com/survey/responses/#{conversation.uuid}"
          expect(presenter.outgoing_content).to include(expected_url)
          expect(presenter.outgoing_content).to include('<p>')
        end
      end

      it 'returns CSAT config message when config exists and dynamically generates survey URL (HTML format)' do
        with_modified_env 'FRONTEND_URL' => 'https://app.chatwoot.com' do
          allow(message.inbox).to receive(:csat_config).and_return({ 'message' => 'Custom CSAT message' })
          expected_url = "https://app.chatwoot.com/survey/responses/#{conversation.uuid}"
          expected_content = "<p>Custom CSAT message #{expected_url}</p>\n"
          expect(presenter.outgoing_content).to eq(expected_content)
        end
      end
    end
  end

  describe '#webhook_content' do
    context 'when message is not input_csat' do
      let(:content_type) { 'text' }
      let(:content) { 'Regular **bold** message' }

      it 'returns raw content without markdown rendering' do
        expect(presenter.webhook_content).to eq('Regular **bold** message')
      end

      it 'strips CommonMark hard-break backslashes before newlines' do
        message.update!(content: "First\\\nSecond\\\nThird\\\nFourth")
        expect(presenter.webhook_content).to eq("First\nSecond\nThird\nFourth")
      end

      it 'preserves backslashes that are not followed by a newline' do
        message.update!(content: "path\\to\\file\\\nNext line")
        expect(presenter.webhook_content).to eq("path\\to\\file\nNext line")
      end

      it 'handles carriage return and newline pairs' do
        message.update!(content: "Line one\\\r\nLine two\\\r\nLine three")
        expect(presenter.webhook_content).to eq("Line one\nLine two\nLine three")
      end

      it 'preserves normal newlines and only strips hard-break newlines' do
        message.update!(content: "line one\\\nline two\n\nline three")
        expect(presenter.webhook_content).to eq("line one\nline two\n\nline three")
      end
    end

    # Regressão B208: a mensagem de canal API (Portal do Cliente) chegava no webhook em markdown cru
    # (`**negrito**`, `![img](url)`) em vez de HTML; o webhook é o único caminho de entrega desse canal
    context 'when the inbox is an API channel (Portal)' do
      let(:conversation) { create(:conversation, inbox: create(:channel_api).inbox) }
      let(:content_type) { 'text' }
      let(:content) { "Regular **bold** message\n\n![assinatura](https://example.com/assinatura.png)" }

      it 'sends the HTML-rendered content instead of the raw markdown' do
        expect(presenter.webhook_content).to include('<strong>bold</strong>', '<img src="https://example.com/assinatura.png"')
        expect(presenter.webhook_content).not_to include('**bold**', '![assinatura]')
      end
    end

    context 'when message is input_csat and inbox is not web widget' do
      let(:content_type) { 'input_csat' }
      let(:content) { 'Rate your experience' }

      before do
        allow(message.inbox).to receive(:web_widget?).and_return(false)
      end

      it 'includes CSAT survey URL without markdown rendering' do
        with_modified_env 'FRONTEND_URL' => 'https://app.chatwoot.com' do
          expected_url = "https://app.chatwoot.com/survey/responses/#{conversation.uuid}"
          expect(presenter.webhook_content).to include(expected_url)
          expect(presenter.webhook_content).not_to include('<p>')
        end
      end
    end
  end

  describe 'delegation' do
    let(:content_type) { 'text' }
    let(:content) { 'Test message' }

    it 'delegates model methods to the wrapped message' do
      expect(presenter.content).to eq('Test message')
      expect(presenter.content_type).to eq('text')
      expect(presenter.conversation).to eq(conversation)
    end
  end
end
