class UploadService
  module ControllerHelper
    def self.prepare(url: nil, file: nil, ref: nil)
      upload = Upload.new

      if Utils.is_downloadable?(url) && file.nil?
        # this gets called from UploadsController#new so we need to preprocess async
        UploadPreprocessJob.perform_later(CurrentUser.id, {source: uri, referer_url: ref})

        begin
          download = Downloads::File.new(url, ref)
          remote_size = download.size
        rescue Exception
        end

        return [upload, remote_size]
      end

      if file
        # this gets called via XHR so we can process sync
        Preprocessor.new(file: file).delayed_start(CurrentUser.id)
      end

      return [upload]
    end
  end
end
