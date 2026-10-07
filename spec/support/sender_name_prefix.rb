# PATCH LOCAL (fork) - mensagem de agente sai pelos canais com "**Nome**: " na
# frente (MessageContentPresenter#content_for_delivery, testado em
# spec/presenters/message_content_presenter_spec.rb). Os specs da mecânica de
# envio de cada canal (endpoint, formato do payload) usam
# :without_sender_name_prefix pra testar só o envio, com o texto que o upstream
# espera.
RSpec.configure do |config|
  config.before(:each, :without_sender_name_prefix) do
    allow_any_instance_of(MessageContentPresenter).to receive(:prepend_sender_name?).and_return(false) # rubocop:disable RSpec/AnyInstance
  end
end
