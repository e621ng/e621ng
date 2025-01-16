# frozen_string_literal: true

# reverts all changes made by a user
class UserRevert
  THRESHOLD = 1_000
  class TooManyChangesError < RuntimeError ; end

  attr_reader :user_id

  def initialize(user_id)
    @user_id = user_id
  end

  def process
    validate!
    revert_post_changes
  end

  def validate!
    if PostVersion.where(updater_id: user_id).count > THRESHOLD
      raise TooManyChangesError.new("This user has too many changes to be reverted")
    end
  end

  def revert_post_changes
    PostVersion.where(updater_id: user_id).find_each do |version|
      version.undo! if version.undoable?
    end
  end

  def self.can_revert?(user)
    user.post_update_count <= THRESHOLD
  end
end
