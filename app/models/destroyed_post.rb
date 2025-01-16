# frozen_string_literal: true

class DestroyedPost < ApplicationRecord
  belongs_to :destroyer, class_name: "User"
  belongs_to :uploader, class_name: "User", optional: true
  after_update :log_notify_change, if: :saved_change_to_notify?

  def log_notify_change
    action = notify? ? :enable_post_notifications : :disable_post_notifications
    StaffAuditLog.log(action, CurrentUser.user, { destroyed_post_id: id, post_id: post_id })
  end

  module SearchMethods
    def search(params)
      q = super

      q = q.where_user(:destroyer_id, :destroyer, params)
      q = q.where_user(:uploader_id, :uploader, params)

      if params[:destroyer_ip_addr].present?
        q = q.where("destroyer_ip_addr <<= ?", params[:destroyer_ip_addr])
      end

      if params[:uploader_ip_addr].present?
        q = q.where("uploader_ip_addr <<= ?", params[:uploader_ip_addr])
      end

      if params[:post_id].present?
        q = q.attribute_matches(:post_id, params[:post_id])
      end

      if params[:md5].present?
        q = q.attribute_matches(:md5, params[:md5])
      end

      q.apply_basic_order(params)
    end
  end

  extend SearchMethods

  def notify_reupload(uploader, replacement_post_id: nil)
    return if notify == false
    reason = "User tried to re-upload \"previously destroyed post ##{post_id}\":/admin/destroyed_posts/#{post_id}"
    reason += " as a replacement for post ##{replacement_post_id}" if replacement_post_id.present?
    Ticket.create!(
      creator_id: User.system.id,
      creator_ip_addr: "127.0.0.1",
      disp_id: uploader.id,
      status: "pending",
      qtype: "user",
      reason: reason,
    ).push_pubsub("create")
  end
end
