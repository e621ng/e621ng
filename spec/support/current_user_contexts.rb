# frozen_string_literal: true

# Shared contexts for setting the current user in specs.
#
# Usage:
#   include_context "as admin"
#   include_context "as moderator"
#   include_context "as janitor"
#   include_context "as privileged"
#   include_context "as member"
#
# Each context sets CurrentUser.user to a freshly created user of the
# corresponding level and sets CurrentUser.ip_addr to "127.0.0.1".
# Both are cleared in an after hook.

{
  "admin"      => :admin_user,
  "moderator"  => :moderator_user,
  "janitor"    => :janitor_user,
  "privileged" => :privileged_user,
  "member"     => :user,
}.each do |role, factory|
  RSpec.shared_context "as #{role}" do
    before do
      CurrentUser.user    = create(factory)
      CurrentUser.ip_addr = "127.0.0.1"
    end

    after do
      CurrentUser.user    = nil
      CurrentUser.ip_addr = nil
    end
  end
end
