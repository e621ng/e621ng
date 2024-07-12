# frozen_string_literal: true

module Admin::UsersHelper
  def user_level_select(object, field)
    options = Danbooru.config.levels.map { |x,y| [x,y] }
    select(object, field, options)
  end
end
