# frozen_string_literal: true

module Populate
  # Imports posts from the live site through the full upload pipeline.
  # Slow (seconds per post), but the files are real. See doc 44 for the export-backed importer.
  class ApiPosts < Base
    DEFAULT_SEARCH = "order:random+score:>150+-grandfathered_content+-rating:e"

    def call
      count = options.fetch(:count, 0)
      return [] unless count > 0
      log "* Creating #{count} posts"

      search = options.fetch(:search, DEFAULT_SEARCH)
      batch_size = options.fetch(:batch_size, 320)
      users = options.fetch(:users, [])
      users = random_users(older_than: 7.days) if users.empty?
      admin = User.find(1)
      output = []

      seed = Faker::Number.within(range: 100_000..100_000_000)
      log "  Seed #{seed}"

      total = 0
      skipped = 0
      page = 1

      while total < count
        # mode=extended returns tags grouped by category; the response is a bare array.
        posts = api_request("/posts.json?tags=#{search}+-young+-type:swf+randseed:#{seed}&limit=#{batch_size}&page=#{page}&mode=extended")
        if !posts.is_a?(Array) || posts.length != batch_size
          log "  End of Content"
          break
        end

        imported = posts.reject { |post| Post.where(md5: post["files"]["meta"]["md5"]).exists? }
        skipped += posts.size - imported.size
        log "  Page #{page}, skipped #{skipped}"

        imported.each do |post|
          post["tags"].each do |category, tags|
            Tag.find_or_create_by_name_list(tags.map { |tag| "#{category}:#{tag}" })
          end

          CurrentUser.user = users.sample
          CurrentUser.user = users.sample unless CurrentUser.user.can_upload_with_reason
          log "  - #{CurrentUser.user.name} : #{post['files']['original']['url']}"

          upload = nil
          Post.transaction do
            upload = UploadService.new(upload_params(post)).start!
          end

          if upload.invalid? || upload.post.nil?
            log "    invalid: #{upload.errors.full_messages.join('; ')}"
          else
            log "    post: ##{upload.post.id}"
            CurrentUser.scoped(admin) { upload.post.approve! }
            total += 1
            output << upload.post
          end

          break if total >= count
        end

        page += 1
      end

      log "  Created #{total}, skipped #{skipped} posts from #{page - 1} pages"
      output
    end

    private

    def api_request(path)
      response = Faraday.get("https://e621.net#{path}", nil, user_agent: "e621ng/seeding")
      JSON.parse(response.body)
    end

    def upload_params(post)
      {
        uploader: CurrentUser.user,
        uploader_ip_addr: LOCAL_IP,
        direct_url: post["files"]["original"]["url"],
        tag_string: post["tags"].values.flatten.join(" "),
        source: post["sources"].join("\n"),
        description: post["description"],
        rating: post["rating"],
      }
    end
  end
end
