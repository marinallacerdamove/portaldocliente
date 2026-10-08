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

  it 'is the pattern of the cnpj preset of the bot extract node' do
    expect(BotFlows::Engine::PRESET_PATTERNS['cnpj']).to eq(described_class::CNPJ_REGEX)
  end
end
