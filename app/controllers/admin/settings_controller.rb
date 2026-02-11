# frozen_string_literal: true

module Admin
  class SettingsController < ApplicationController
    before_action :admin_only
    before_action :is_bd_staff_only
    before_action :check_if_using_config_file
    respond_to :html, :json

    def show
    end

    def update
      settings_params.each_pair do |k, v|
        # TODO: Accumulate errors for invalid input?
        next unless v.present? && Setting.respond_to?(k)
        # TODO: Account for other types?
        case Setting.get_field(k)[:type]
        when :boolean
          Setting.send("#{k}=", Setting.deserialize_boolean(v))
        when :enum_field
          Setting.send("#{k}=", v)
        else
          next # TODO: Accumulate error here?
        end
      end
      redirect_to admin_settings_path
    end

    private

    def settings_params
      params.require(:settings).permit(*Setting::GENERAL_SETTINGS)
    end

    def check_if_using_config_file
      access_denied("Using config file; settings are unassignable at runtime. Please speak to your system administrator to change `danbooru_default_config.rb`/`danbooru_local_config.rb`.") if Setting::GENERAL_SETTINGS.blank?
    end
  end
end
