# frozen_string_literal: true

module Moderator
  class PostDiffsController < ApplicationController
    before_action :janitor_only

    def show
      return unless params[:post_a].present? && params[:post_b].present?

      @post_a = ::Post.find(params[:post_a])
      @post_b = ::Post.find(params[:post_b])

      raise User::PrivilegeError, "Post unavailable" unless Security::Lockdown.post_visible?(@post_a, CurrentUser.user)
      raise User::PrivilegeError, "Post unavailable" unless Security::Lockdown.post_visible?(@post_b, CurrentUser.user)
    end
  end
end
