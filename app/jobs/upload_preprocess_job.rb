class UploadPreprocessJob < ApplicationJob
  queue_as :default

  def perform(*args)
    user_id = args[0]
    params = args[1]
    Preprocessor.new(source: params[:url], referer_url: params[:ref]).delay_start(user_id)
  end
end
