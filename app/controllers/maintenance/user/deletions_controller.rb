# frozen_string_literal: true

module Maintenance
  module User
    class DeletionsController < ApplicationController
      before_action :logged_in_only

      def show
      end

      def destroy
        deletion = UserDeletion.new(CurrentUser.user, params[:password])
        deletion.delete!
        cookies.delete :remember
        session.delete(:user_id)
        redirect_to(posts_path, :notice => "You are now logged out")
      rescue UserDeletion::ValidationError => e
        render_expected_error(400, e)
      end
    end
  end
end
