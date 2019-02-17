class TagImplicationJob < ApplicationJob
  queue_as :tags

  def perform(*args)
    ti = TagImplication.find(args[0])
    ti.process!(args[1])
  end
end
