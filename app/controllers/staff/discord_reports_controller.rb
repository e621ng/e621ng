# frozen_string_literal: true

module Staff
  class DiscordReportsController < ApplicationController
    before_action :admin_only

    def index
      @janitor_report = DiscordReport::JanitorStats.new.report(update_cache: false)
      @moderator_report = DiscordReport::ModeratorStats.new.report(update_cache: false)
      @aibur_report = DiscordReport::AiburStats.new.report(update_cache: false)
    end
  end
end
