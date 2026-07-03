# frozen_string_literal: true

module Admin::UsersHelper
  def user_level_select(object, field)
    options = UserLevel::ASSIGNABLE_LEVELS.map { |x,y| [x,y] }
    select(object, field, options)
  end
end
