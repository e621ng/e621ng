# frozen_string_literal: true

class Maintenance::User::LoginReminderMailerPreview < ActionMailer::Preview # rubocop:disable Style/ClassAndModuleChildren
  def notice
    Maintenance::User::LoginReminderMailer.notice(User.first)
  end
end
