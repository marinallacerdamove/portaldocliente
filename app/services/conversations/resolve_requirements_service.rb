# PATCH LOCAL (fork) - o que falta pra um agente resolver a conversa, as mesmas
# travas do botão Resolver (ResolveAction.vue): "Ações da conversa"
# (helper/conversationRequiredActions.js), campos adicionais obrigatórios na
# conclusão (useConversationCustomFields.js) e motivo de encerramento. Cobrado
# no servidor pra quem resolve pela tela (inclusive em massa) sem passar por
# essa checagem. Integração (Portal, automação) não passa por aqui - ver
# ResolveRequirementsGuard.
class Conversations::ResolveRequirementsService
  # Ações da conversa cobradas quando a conta tem o atributo cadastrado.
  REQUIRED_ACTION_ATTRIBUTE_KEYS = %w[empresa tipo_de_solicitao servico].freeze
  CLOSE_REASON_ATTRIBUTE_KEY = 'motivo_encerramento'.freeze
  CUSTOM_FIELDS_ATTRIBUTE_KEY = 'campos_adicionais'.freeze
  STATUS_ATTRIBUTE_KEY = 'status_atendimento'.freeze
  INTERNAL_TICKETS_INBOX_NAME = 'Tickets Internos'.freeze
  # "Aberto via" do Movidesk pelo canal da caixa (conversationOrigin no front).
  CHANNEL_ORIGINS = {
    'Channel::Api' => 'cliente',
    'Channel::Whatsapp' => 'whatsapp',
    'Channel::Email' => 'email',
    'Channel::WebWidget' => 'chat'
  }.freeze

  def initialize(conversation)
    @conversation = conversation
    @account = conversation.account
    @attributes = conversation.custom_attributes || {}
  end

  # Nomes do que falta, na ordem em que a tela cobra.
  def missing
    missing_actions + missing_custom_fields + missing_close_reason
  end

  private

  def blank?(value)
    TicketFieldRulesEvaluator.empty_value?(value)
  end

  def definitions
    @definitions ||= @account.custom_attribute_definitions.conversation_attribute.index_by(&:attribute_key)
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
    labels << 'Time' if @conversation.team_id.blank? && @account.teams.exists?
    labels
  end

  def missing_custom_fields
    evaluator = TicketFieldRulesEvaluator.new(
      rules: TicketFieldRule.where(account_id: @account.id).ordered,
      fields: TicketCustomField.where(account_id: @account.id).to_a
    )
    items = evaluator.visible_items(context).select { |item| item['editable_by_agents'] }
    TicketFieldRulesEvaluator.missing_required(items, custom_field_values, ['conclusao']).map { |item| item['field'].name }
  end

  def missing_close_reason
    definition = definitions[CLOSE_REASON_ATTRIBUTE_KEY]
    definition && blank?(@attributes[CLOSE_REASON_ATTRIBUTE_KEY]) ? [definition.attribute_display_name] : []
  end

  def custom_field_values
    @attributes[CUSTOM_FIELDS_ATTRIBUTE_KEY] || {}
  end

  def context
    {
      servico: @attributes['servico'],
      tipo_de_solicitacao: @attributes['tipo_de_solicitao'],
      status: @attributes[STATUS_ATTRIBUTE_KEY],
      concluded: @conversation.resolved?,
      origem: origin,
      empresa: @attributes['empresa'],
      equipe: @conversation.team&.name,
      responsavel: @conversation.assignee&.name,
      values: custom_field_values
    }
  end

  def origin
    inbox = @conversation.inbox
    inbox.name == INTERNAL_TICKETS_INBOX_NAME ? 'agente' : CHANNEL_ORIGINS[inbox.channel_type].to_s
  end
end
