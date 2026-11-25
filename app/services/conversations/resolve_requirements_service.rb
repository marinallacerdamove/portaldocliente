# PATCH LOCAL (fork) - o que falta pra um agente resolver a conversa, as mesmas
# travas do botão Resolver (ResolveAction.vue): "Ações da conversa"
# (helper/conversationRequiredActions.js), campos adicionais obrigatórios na
# conclusão (useConversationCustomFields.js) e motivo de encerramento. Cobrado
# no servidor pra quem resolve pela tela (inclusive em massa) sem passar por
# essa checagem. Integração (Portal, automação) não passa por aqui - ver
# ResolveRequirementsGuard. Com user:, campo restrito a outras equipes
# (TicketFieldRulesEvaluator.agent_can_edit?) não é cobrado dele.
class Conversations::ResolveRequirementsService
  # Ações da conversa cobradas quando a conta tem o atributo cadastrado.
  REQUIRED_ACTION_ATTRIBUTE_KEYS = [TicketContract::COMPANY_KEY, TicketContract::CATEGORY_KEY, TicketContract::SERVICE_KEY].freeze
  # "Aberto via" do Movidesk pelo canal da caixa (conversationOrigin no front).
  CHANNEL_ORIGINS = {
    'Channel::Api' => 'cliente',
    'Channel::Whatsapp' => 'whatsapp',
    'Channel::Email' => 'email',
    'Channel::WebWidget' => 'chat'
  }.freeze

  # O que vem da conta e não muda de uma conversa pra outra; quem confere várias
  # conversas (resolver em massa) calcula uma vez e passa em account_data.
  AccountData = Struct.new(:definitions, :evaluator, :teams_exist, keyword_init: true)

  def self.account_data(account)
    AccountData.new(
      definitions: account.custom_attribute_definitions.conversation_attribute.index_by(&:attribute_key),
      evaluator: TicketFieldRulesEvaluator.new(
        rules: TicketFieldRule.where(account_id: account.id).ordered, fields: TicketCustomField.where(account_id: account.id).to_a
      ),
      teams_exist: account.teams.exists?
    )
  end

  def initialize(conversation, account_data: nil, user: nil)
    @conversation = conversation
    @user = user
    @account = conversation.account
    @attributes = conversation.custom_attributes || {}
    @account_data = account_data || self.class.account_data(@account)
  end

  # Obrigatórios "na abertura" para quem abre pela tela do agente (Movidesk: "Na abertura").
  OPENING_MOMENTS = %w[abertura_agente abertura].freeze

  # Nomes do que falta, na ordem em que a tela cobra.
  def missing
    missing_actions + missing_custom_fields(['conclusao']) + missing_close_reason
  end

  # Campos adicionais obrigatórios na abertura que faltam num ticket ainda não gravado (B31):
  # mesma avaliação da conclusão, com os momentos da abertura.
  def missing_on_opening
    missing_custom_fields(OPENING_MOMENTS)
  end

  # Chaves dos campos que a regra mostra e que o usuário não edita por não ser
  # da equipe (o servidor ignora o valor que ele mandar). Sem user: nenhuma.
  def team_locked_field_keys
    @account_data.evaluator.visible_items(context)
                 .reject { |item| TicketFieldRulesEvaluator.team_allowed?(item, editor) }
                 .map { |item| item['field'].key }
  end

  private

  def blank?(value)
    TicketFieldRulesEvaluator.empty_value?(value)
  end

  def definitions
    @account_data.definitions
  end

  def missing_actions
    attributes = REQUIRED_ACTION_ATTRIBUTE_KEYS.filter_map do |key|
      definitions[key].attribute_display_name if definitions[key] && blank?(@attributes[key])
    end
    attributes + missing_native_actions
  end

  # Time só é cobrado quando a conta tem time (senão não teria como preencher).
  def missing_native_actions
    labels = []
    labels << 'Prioridade' if @conversation.priority.blank?
    labels << 'Agente' if @conversation.assignee_id.blank?
    labels << 'Time' if @conversation.team_id.blank? && @account_data.teams_exist
    labels
  end

  def missing_custom_fields(moments)
    items = @account_data.evaluator.visible_items(context).select { |item| TicketFieldRulesEvaluator.agent_can_edit?(item, editor) }
    TicketFieldRulesEvaluator.missing_required(items, custom_field_values, moments).map { |item| item['field'].name }
  end

  # Só consulta papel e equipes quando há usuário.
  def editor
    return if @user.nil?

    @editor ||= {
      admin: @account.account_users.find_by(user: @user)&.administrator?,
      team_names: @account.teams.joins(:team_members).where(team_members: { user_id: @user.id }).pluck(:name)
    }
  end

  def missing_close_reason
    definition = definitions[TicketContract::CLOSE_REASON_KEY]
    definition && blank?(@attributes[TicketContract::CLOSE_REASON_KEY]) ? [definition.attribute_display_name] : []
  end

  def custom_field_values
    @attributes[TicketContract::CUSTOM_FIELDS_KEY] || {}
  end

  def context
    {
      servico: @attributes[TicketContract::SERVICE_KEY],
      tipo_de_solicitacao: @attributes[TicketContract::CATEGORY_KEY],
      status: @attributes[TicketContract::STATUS_KEY],
      concluded: @conversation.resolved?,
      origem: origin,
      empresa: @attributes[TicketContract::COMPANY_KEY],
      equipe: @conversation.team&.name,
      responsavel: @conversation.assignee&.name,
      values: custom_field_values
    }
  end

  # Ticket interno aberto pelo Portal cai na caixa API (origem "cliente" pelo
  # canal), mas o Portal grava visivel_parceiro=false e o chama de "agente".
  # Mesma regra de conversationOrigin no front.
  def origin
    return 'agente' if [false, 'false'].include?(@attributes[TicketContract::PARTNER_VISIBLE_KEY])

    inbox = @conversation.inbox
    inbox.name == TicketContract::INTERNAL_TICKETS_INBOX_NAME ? 'agente' : CHANNEL_ORIGINS[inbox.channel_type].to_s
  end
end
