# frozen_string_literal: true

# Daily prune of user_ip_addresses rows unseen for the retention period. This is
# the sole expiry mechanism for the table; account deletion deliberately leaves
# rows behind (the delete-and-re-register evasion pattern depends on them), so
# the prune applies uniformly to active and deleted accounts.
class UserIpAddressPruneJob < ApplicationJob
  sidekiq_options queue: "low_prio"

  def perform
    UserIpAddress.without_timeout do
      UserIpAddress
        .where(last_seen_at: ...Danbooru.config.user_ip_retention_period.ago)
        .in_batches(load: false)
        .delete_all
    end
  end
end
