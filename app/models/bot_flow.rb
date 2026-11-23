# == Schema Information
#
# Table name: bot_flows
#
#  id              :bigint           not null, primary key
#  active          :boolean          default(TRUE), not null
#  description     :text
#  edges           :jsonb            not null
#  inbox_ids       :bigint           default([]), not null, is an Array
#  name            :string           not null
#  nodes           :jsonb            not null
#  priority        :integer          default(0), not null
#  trigger_config  :jsonb            not null
#  trigger_type    :integer          default("conversation_created"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#
# Indexes
#
#  index_bot_flows_on_account_id  (account_id)
#  index_bot_flows_on_inbox_ids   (inbox_ids) USING gin
#
class BotFlow < ApplicationRecord
  belongs_to :account

  enum trigger_type: { conversation_created: 0, keyword: 1 }

  NODE_TYPES = %w[start send_message menu ask_and_extract condition extract_pattern webhook chatwoot_action cnpj_lookup
                  receita_cnpj_lookup].freeze
  NODE_REQUIRED_FIELDS = {
    'start' => [],
    'send_message' => ['text'],
    'menu' => %w[prompt options],
    'ask_and_extract' => %w[prompt variable_name],
    'condition' => ['branches'],
    'extract_pattern' => %w[source_variable pattern target_variable],
    'webhook' => %w[url method],
    'chatwoot_action' => ['action_name'],
    'cnpj_lookup' => ['source_variable'],
    'receita_cnpj_lookup' => ['source_variable']
  }.freeze
  # Únicas ações que o nó "Ação do Chatwoot" pode executar (as que o
  # ChatwootActionPanel.vue oferece, ver BOT_FLOW_CHATWOOT_ACTIONS). O nome vai
  # pra public_send no BotFlows::Engine, então nada fora desta lista.
  CHATWOOT_ACTIONS = %w[assign_team add_label set_custom_attribute resolve_conversation].freeze

  validates :name, presence: true
  validates :account_id, presence: true
  validate :json_nodes_format
  validate :json_edges_format
  validate :exactly_one_start_node
  validate :inbox_ids_belong_to_whatsapp_inboxes

  scope :active, -> { where(active: true) }
  scope :for_inbox, ->(inbox_id) { where('inbox_ids @> ARRAY[?]::bigint[]', inbox_id) }

  private

  def json_nodes_format
    return if nodes.blank?

    unless nodes.is_a?(Array)
      errors.add(:nodes, 'must be an array')
      return
    end

    ids = nodes.map { |n| n['id'] }
    errors.add(:nodes, 'node ids must be unique') if ids.uniq.length != ids.length

    nodes.each_with_index do |node, index|
      type = node.is_a?(Hash) ? node['type'] : nil
      unless NODE_TYPES.include?(type)
        errors.add(:nodes, "node #{index}: type '#{type}' not supported")
        next
      end

      missing = NODE_REQUIRED_FIELDS[type] - node.keys
      errors.add(:nodes, "node #{index}: missing #{missing.join(', ')}") if missing.any?
      validator = NODE_VALIDATORS[type]
      send(validator, node, index) if validator
    end
  end

  NODE_VALIDATORS = { 'chatwoot_action' => :validate_chatwoot_action, 'menu' => :validate_menu_limits }.freeze

  # PATCH LOCAL: WhatsApp limits for the interactive menu (Whatsapp::Providers::BaseService turns up
  # to 3 options into buttons, more into a list). Past them the message is refused and the flow waits
  # forever (B80).
  MENU_MAX_OPTIONS = 10
  MENU_BUTTON_OPTIONS = 3
  MENU_BUTTON_LABEL_MAX = 20
  MENU_LIST_LABEL_MAX = 24

  def validate_menu_limits(node, index)
    options = Array(node['options'])
    errors.add(:nodes, "node #{index}: menu allows at most #{MENU_MAX_OPTIONS} options") if options.size > MENU_MAX_OPTIONS
    max = options.size <= MENU_BUTTON_OPTIONS ? MENU_BUTTON_LABEL_MAX : MENU_LIST_LABEL_MAX
    too_long = options.select { |option| option.is_a?(Hash) && option['label'].to_s.length > max }
    errors.add(:nodes, "node #{index}: menu labels up to #{max} characters") if too_long.any?
  end

  def validate_chatwoot_action(node, index)
    return if CHATWOOT_ACTIONS.include?(node['action_name'])

    errors.add(:nodes, "node #{index}: action '#{node['action_name']}' not supported")
  end

  def json_edges_format
    return if edges.blank?

    unless edges.is_a?(Array)
      errors.add(:edges, 'must be an array')
      return
    end

    node_ids = Array(nodes).filter_map { |n| n['id'] if n.is_a?(Hash) }.to_set
    edges.each_with_index do |edge, index|
      next if edge.is_a?(Hash) && node_ids.include?(edge['source']) && node_ids.include?(edge['target'])

      errors.add(:edges, "edge #{index}: source/target must reference existing nodes")
    end
  end

  def exactly_one_start_node
    return if nodes.blank?

    start_count = nodes.count { |n| n.is_a?(Hash) && n['type'] == 'start' }
    errors.add(:nodes, 'must contain exactly one start node') if start_count != 1
  end

  def inbox_ids_belong_to_whatsapp_inboxes
    return if inbox_ids.blank?

    valid_ids = account.inboxes.where(id: inbox_ids, channel_type: 'Channel::Whatsapp').pluck(:id)
    invalid = inbox_ids - valid_ids
    errors.add(:inbox_ids, "must reference WhatsApp inboxes on this account (invalid: #{invalid.join(', ')})") if invalid.any?
  end
end
