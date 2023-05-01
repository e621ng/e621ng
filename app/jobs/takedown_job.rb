# frozen_string_literal: true

class TakedownJob < ApplicationJob
  queue_as :high_prio
  sidekiq_options lock: :until_executing, lock_args_method: :lock_args

  def self.lock_args(args)
    [args[0]]
  end

  def perform(id, approver, del_reason)
    @takedown = Takedown.find(id)
    @approver = User.find(approver)
    @takedown.approver_id = @approver.id
    CurrentUser.scoped(@approver) do
      ModAction.log(:takedown_process, { takedown_id: @takedown.id })
    end

    CurrentUser.as_system do
      @takedown.status = @takedown.calculated_status
      @takedown.save!
      @takedown.actual_posts.find_each do |p|
        if @takedown.should_delete(p.id)
          next if p.is_deleted?
          p.delete!("takedown ##{@takedown.id}: #{del_reason}", { force: true })
        else
          next unless p.is_deleted?
          p.undelete!({ force: true })
        end
      end
    end
  end
end
