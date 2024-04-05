# frozen_string_literal: true

module Maintenance
  module User
    class PasswordsController < ApplicationController
      def edit
        @user = CurrentUser.user
      end
    end
  end
end
