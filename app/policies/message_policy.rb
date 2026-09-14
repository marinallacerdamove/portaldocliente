class MessagePolicy < ApplicationPolicy
  def update?
    administrator? || own_message?
  end

  private

  def administrator?
    account_user&.administrator?
  end

  def own_message?
    record.sender_type == 'User' && record.sender_id == user.id
  end
end
