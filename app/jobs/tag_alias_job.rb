class TagAliasJob < ApplicationJob
  queue_as :tags

  def perform(*args)
    ta = TagAlias.find(args[0])
    ta.process!(update_topic: args[1])
  end
end
