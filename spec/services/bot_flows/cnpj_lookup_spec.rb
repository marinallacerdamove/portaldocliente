require 'rails_helper'

RSpec.describe BotFlows::CnpjLookup do
  describe 'CNPJ_REGEX' do
    def extract(text)
      text[described_class::CNPJ_REGEX]
    end

    it 'finds a numeric CNPJ with or without punctuation' do
      expect(extract('meu cnpj é 12.345.678/0001-95, obrigado')).to eq('12.345.678/0001-95')
      expect(extract('12345678000195')).to eq('12345678000195')
    end

    it 'finds an alphanumeric CNPJ' do
      expect(extract('cnpj: 12.ABC.345/01DE-35')).to eq('12.ABC.345/01DE-35')
      expect(extract('12ABC34501DE35')).to eq('12ABC34501DE35')
    end

    it 'keeps finding the numeric CNPJ glued to a word' do
      expect(extract('cnpj12345678000195')).to eq('12345678000195')
    end

    it 'does not take a piece of a longer alphanumeric word' do
      expect(extract('protocolo ABCDEFGHIJKLMNOP12 aberto')).to be_nil
    end
  end

  describe '#call' do
    let(:conversation) { create(:conversation) }
    let(:node) { { 'source_variable' => 'resposta' } }
    let(:vars) { { 'resposta' => 'meu cnpj 12.345.678/0001-95' } }

    it 'asks the Portal with the internal token and the account header' do
      captured = nil
      allow(SafeFetch).to receive(:fetch) do |url, **options|
        captured = { url: url, headers: options[:headers] }
      end

      with_modified_env PORTAL_INTERNAL_API_URL: 'http://portal.test', PORTAL_INTERNAL_API_TOKEN: 'segredo' do
        handle, = described_class.new(node, vars, conversation).call
        expect(handle).to eq('not_found')
      end

      expect(captured[:url]).to eq('http://portal.test/api/internal/empresa_by_cnpj?cnpj=12.345.678%2F0001-95')
      expect(captured[:headers]).to eq('X-Internal-Token' => 'segredo', 'X-Chatwoot-Account-Id' => conversation.account_id.to_s)
    end

    it 'does not call the Portal when there is no CNPJ in the answer' do
      allow(SafeFetch).to receive(:fetch)

      handle, = described_class.new(node, { 'resposta' => 'sem numero' }, conversation).call

      expect(handle).to eq('not_found')
      expect(SafeFetch).not_to have_received(:fetch)
    end
  end

  it 'is the pattern of the cnpj preset of the bot extract node' do
    expect(BotFlows::Engine::PRESET_PATTERNS['cnpj']).to eq(described_class::CNPJ_REGEX)
  end
end
