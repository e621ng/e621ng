class TakedownJob < ApplicationJob
  queue_as :high_prio

  def perform(*args)
    del_reason = args[2]
    @takedown = Takedown.find(args[0])
    @approver = User.find(args[1])
    @takedown.approver_id = @approver.id
    CurrentUser.as(@approver) do
      ModAction.log(:takedown_process, {takedown_id: @takedown.id})
    end

    CurrentUser.as_system do
      @takedown.status = @takedown.calculated_status
      @takedown.save!
      @takedown.actual_posts.find_each do |p|
        if @takedown.should_delete(p.id)
          next if p.is_deleted?
          p.delete!("takedown ##{@takedown.id}: #{del_reason}", {force: true, without_mod_action: true})
        else
          next unless p.is_deleted?
          p.undelete!({force: true, without_mod_action: true})
        end
      end
    end
  end

end
