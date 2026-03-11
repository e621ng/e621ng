# frozen_string_literal: true

module Moderator
  class PostDiffsController < ApplicationController
    before_action :janitor_only

    def show
      return unless params[:post_a].present? && params[:post_b].present?

      if params[:post_a].match(/\A\d+\z/)
        @post_a = ::Post.find(params[:post_a])
      else
        @post_a = ::Post.find_by(md5: params[:post_a])
        unless @post_a
          @replacement_a = ::PostReplacement.find_by(md5: params[:post_a])
          @post_a = @replacement_a.post if @replacement_a
        end
      end

      if params[:post_b].match(/\A\d+\z/)
        @post_b = ::Post.find(params[:post_b])
      else
        @post_b = ::Post.find_by(md5: params[:post_b])
        unless @post_b
          @replacement_b = ::PostReplacement.find_by(md5: params[:post_b])
          @post_b = @replacement_b.post if @replacement_b
        end
      end

      return if @post_a.nil? || @post_b.nil?

      raise User::PrivilegeError, "Post unavailable" unless Security::Lockdown.post_visible?(@post_a, CurrentUser.user)
      raise User::PrivilegeError, "Post unavailable" unless Security::Lockdown.post_visible?(@post_b, CurrentUser.user)
    end
  end
end
