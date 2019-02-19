class SavedSearchJob < ApplicationJob
  queue_as :default

  def perform(*args)
    SavedSearch.populate(args[0])
  end
end
