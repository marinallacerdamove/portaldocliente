# PATCH LOCAL (fork) - vínculo pai/filho entre tickets (Movidesk). O filho
# guarda o pai em ticket_pai_id e o pai lista os filhos em ticket_filhos_ids
# (CSV), sempre por display_id. As pontas mudam juntas numa transação, com as
# conversas travadas: o filho sai da lista do pai antigo, a lista não repete
# id e não fica vínculo pela metade. O Portal lê só ticket_pai_id.
# Usado pelo TicketLinkDialog (Conversations::TicketLinksController), pela
# criação de ticket pai/filho (Conversations::InternalTicketService) e pelo
# gatilho "Criar novo ticket filho" (AutomationRules::ActionService).
class Conversations::TicketLinkService
  class InvalidLink < StandardError; end

  MAX_ANCESTORS = 50

  def initialize(parent:, child:)
    @parent = parent
    @child = child
  end

  # Conversas cujo vínculo mudou (pai, filho e, se houver, o pai antigo).
  def perform
    raise InvalidLink, 'self' if @parent.id == @child.id

    ActiveRecord::Base.transaction do
      parent, child = locked(@parent, @child)
      raise InvalidLink, 'cycle' if ancestor?(child, of: parent)

      previous_parent = previous_parent_of(child, parent)
      detach(previous_parent, child) if previous_parent
      write(child, TicketContract::PARENT_TICKET_KEY => parent.display_id.to_s)
      write(parent, TicketContract::CHILD_TICKETS_KEY => (child_ids(parent) | [child.display_id.to_s]).join(','))
      [parent, child, previous_parent].compact
    end
  end

  private

  def ancestor?(candidate, of:)
    current = of
    MAX_ANCESTORS.times do
      parent_id = current.custom_attributes[TicketContract::PARENT_TICKET_KEY]
      return false if parent_id.blank?
      return true if parent_id.to_s == candidate.display_id.to_s

      current = find_conversation(parent_id)
      return false unless current
    end
    false
  end

  def previous_parent_of(child, parent)
    previous_parent = find_conversation(child.custom_attributes[TicketContract::PARENT_TICKET_KEY])
    locked(previous_parent).first if previous_parent && previous_parent.id != parent.id
  end

  # Cópias frescas, travadas (FOR UPDATE) até o fim da transação, na ordem
  # do id pra duas vinculações simultâneas não se travarem.
  def locked(*conversations)
    rows = Conversation.where(id: conversations.map(&:id)).order(:id).lock.index_by(&:id)
    conversations.map { |conversation| rows.fetch(conversation.id) }
  end

  def detach(previous_parent, child)
    remaining = child_ids(previous_parent) - [child.display_id.to_s]
    attributes = previous_parent.custom_attributes.except(TicketContract::CHILD_TICKETS_KEY)
    attributes[TicketContract::CHILD_TICKETS_KEY] = remaining.join(',') if remaining.any?
    previous_parent.update!(custom_attributes: attributes)
  end

  def write(conversation, changes)
    conversation.update!(custom_attributes: conversation.custom_attributes.merge(changes))
  end

  def child_ids(conversation)
    conversation.custom_attributes[TicketContract::CHILD_TICKETS_KEY].to_s.split(',').compact_blank
  end

  def find_conversation(display_id)
    return if display_id.blank?

    @parent.account.conversations.find_by(display_id: display_id)
  end
end
