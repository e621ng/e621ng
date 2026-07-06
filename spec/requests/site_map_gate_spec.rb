# frozen_string_literal: true

require "rails_helper"

# Instantiable level => factory that produces a verified user at that level.
SITE_MAP_LEVEL_FACTORY = {
  UserLevel::BLOCKED => :banned_user,
  UserLevel::MEMBER => :user,
  UserLevel::PRIVILEGED => :privileged_user,
  UserLevel::FORMER_STAFF => :former_staff_user,
  UserLevel::STAFF => :staff_user,
  UserLevel::JANITOR => :janitor_user,
  UserLevel::MODERATOR => :moderator_user,
  UserLevel::ADMIN => :admin_user,
}.freeze

# Access-level guarantee for the site map: each registered page's declared level
# is verified by request — reachable at that level, denied one level below. Gates
# that are not a level boundary opt out via `gate: :inline`.
RSpec.describe "SiteMap gate probe" do
  # Highest instantiable level strictly below `level`, or nil (anonymous).
  def self.level_below(level)
    SITE_MAP_LEVEL_FACTORY.keys.select { |candidate| candidate < level }.max
  end

  def expect_not_errored(path)
    expect(response).not_to have_http_status(:server_error),
                            "GET #{path} returned #{response.status} — couldn't verify the gate. " \
                            "Add fixtures so the page renders, or mark the entry gate: :inline."
  end

  def expect_reachable(path)
    expect_not_errored(path)
    expect(response).to have_http_status(:success), "expected #{path} to be reachable (2xx), got #{response.status}"
  end

  def expect_denied(path)
    expect_not_errored(path)
    # Logged-in-but-insufficient => 403; anonymous => 302 redirect to login.
    expect(response).to have_http_status(:forbidden).or(redirect_to(new_session_path(url: path))),
                        "expected #{path} to be denied (403 or login redirect), got #{response.status}"
  end

  # Some pages 500 on empty data because the backing record/cache the view
  # assumes is only present after the app has run. Seed exactly what the
  # probed path needs so the gate — not missing data — is what we measure.
  def seed_fixtures(entry)
    case entry.route
    when :help_page, :help_pages
      name = entry.route == :help_page ? entry.params[:id] : Danbooru.config.help_landing_page
      # Creating a HelpPage (and its wiki page) needs a non-limited current user.
      CurrentUser.scoped(create(:admin_user)) do
        create(:help_page, name: name)
      end
    when :stats
      # StatsController reads the "e6stats" Redis key and the view assumes it is
      # populated; an empty cache renders a 500. Generate the stats the way the
      # daily job does (needs at least one post to derive the start date).
      CurrentUser.scoped(create(:admin_user)) do
        create(:post)
        StatsUpdater.run!
      end
    end
  end

  SiteMap.probeable_entries.each do |entry|
    path = SiteMap.probe_path(entry)

    if entry.level.nil?
      it "‘#{entry.label}’ (#{path}) is reachable anonymously" do
        seed_fixtures(entry)
        get path
        expect_reachable(path)
      end
    else
      it "‘#{entry.label}’ (#{path}) is reachable at its level and denied below it" do
        seed_fixtures(entry)
        aggregate_failures do
          sign_in_as create(SITE_MAP_LEVEL_FACTORY.fetch(entry.level))
          get path
          expect_reachable(path)

          lower = self.class.level_below(entry.level)
          if lower
            sign_in_as create(SITE_MAP_LEVEL_FACTORY.fetch(lower))
          else
            sign_in_as User.anonymous
          end
          get path
          expect_denied(path)
        end
      end
    end
  end
end
