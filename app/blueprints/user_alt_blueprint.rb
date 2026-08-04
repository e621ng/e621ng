# frozen_string_literal: true

# Serializes a UserAltFinder candidate for the moderator API. Exposes only
# evidence DERIVED from IPs (counts, ratios, date ranges, rarity) — never an IP
# or subnet value in any form. Renders the plain candidate hashes the finder
# returns.
class UserAltBlueprint < Blueprinter::Base
  field :user_id
  field :score
  field :handoff
  field :handoff_users
  field :shared_exact
  field :shared_subnet
  field :total_ips
  field :ratio
  field :rarest_users
  field :overlap_first
  field :overlap_last
  field :last_co_seen
  field :concurrent
  field :deleted

  field :user do |candidate|
    user = candidate[:user]
    next nil unless user

    {
      id: user.id,
      name: user.name,
      level_string: user.level_string,
      created_at: user.created_at,
    }
  end
end
