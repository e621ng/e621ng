# frozen_string_literal: true

# Daily prune of user_sessions: revoked and expired rows are kept for
# UserSession::RETENTION so a compromised account's history is still visible
# from the console; rows never used after login go after an hour.
class UserSessionPruneJob < ApplicationJob
  sidekiq_options queue: "low_prio"

  def perform
    UserSession.prune!
  end
end
