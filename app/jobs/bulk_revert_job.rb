class BulkRevertJob < ApplicationJob
  queue_as :low_prio

  def perform(*args)
    user = User.find(args[0])
    constraints = args[1]

    reverter = BulkRevert.new
    reverter.process(user, constraints)
  end
end
