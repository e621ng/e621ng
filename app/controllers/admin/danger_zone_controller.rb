module Admin
  class DangerZoneController < ApplicationController
    before_action :admin_only

    def index
    end

    def enable_uploads
      DangerZone.enable_uploads
      StaffAuditLog.log(:uploads_enable, CurrentUser.user)
      redirect_to admin_danger_zone_index_path
    end

    def disable_uploads
      DangerZone.disable_uploads
      StaffAuditLog.log(:uploads_disable, CurrentUser.user)
      redirect_to admin_danger_zone_index_path
    end
  end
end
