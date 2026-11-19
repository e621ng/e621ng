# frozen_string_literal: true

# Development data generators. See db/populate/ and design doc 44.
#
#   bin/rails populate:users COUNT=10
#   bin/rails populate:all USERS=10 POSTS=100
#
# Per-type tasks read COUNT (and the knobs listed next to them); populate:all
# reads the historical per-type variables and falls back to defaults when none
# is set.
namespace :populate do
  def populate_prepare
    require Rails.root.join("db/populate").to_s
    ENV["DANBOORU_DISABLE_THROTTLES"] ||= "true"
    Populate.setup_current_user!
  end

  def populate_int(name, default)
    ENV.fetch(name, default).to_i
  end

  def populate_common
    { distribution: populate_int("DISTRIBUTION", 10) }
  end

  # task name => [generator class name, default COUNT, extra options from ENV].
  # Class names are resolved at run time because db/populate is only required by populate_prepare.
  def populate_count_tasks
    {
      users: [:Users, 10, -> { { password: ENV.fetch("PASSWORD", Populate::DEFAULT_PASSWORD) } }],
      comments: [:Comments, 100, -> { {} }],
      favorites: [:Favorites, 100, -> { {} }],
      forums: [:Forums, 100, -> { {} }],
      post_votes: [:PostVotes, 100, -> { {} }],
      comment_votes: [:CommentVotes, 100, -> { {} }],
      pools: [:Pools, 100, -> { {} }],
      dmails: [:Dmails, 10, -> { {} }],
    }
  end

  def populate_all_defaults
    {
      "USERS" => 10, "POSTS" => 100, "COMMENTS" => 100, "FAVORITES" => 100, "FORUMS" => 100,
      "POSTVOTES" => 100, "COMVOTES" => 100, "POOLS" => 100, "FURIDS" => 0, "DM" => 0,
      "TRENDS" => 7, "TRENDS_HOURS" => 48,
    }
  end

  populate_count_tasks.each do |name, (generator, default, extra)|
    desc "Generate #{name.to_s.tr('_', ' ')} (COUNT, DISTRIBUTION)"
    task name => :environment do
      populate_prepare
      Populate.const_get(generator).new(count: populate_int("COUNT", default), **populate_common, **extra.call).call
    end
  end

  def populate_exports_dir
    ENV.fetch("EXPORTS_DIR", Populate::Exports.default_dir)
  end

  namespace :exports do
    desc "Load db/exports/*.csv.gz into the seed schema (TABLES, EXPORTS_DIR, FORCE)"
    task load: :environment do
      populate_prepare
      tables = ENV["TABLES"].present? ? ENV["TABLES"].split(",").map(&:strip) : Populate::Exports::DEFAULT_TABLES
      Populate::Exports.load!(tables: tables, dir: populate_exports_dir, force: ENV["FORCE"].to_s.truthy?)
    end
  end

  def populate_post_options
    {
      count: populate_int("COUNT", 100),
      range: ENV["RANGE"].presence,
      query: ENV.fetch("QUERY", "score:>150 -grandfathered_content -rating:e -young -type:swf"),
      media: ENV.fetch("MEDIA", "placeholder"),
      threads: populate_int("MEDIA_THREADS", Etc.nprocessors.clamp(2, 16)),
      reindex: ENV.fetch("REINDEX", "true").truthy?,
      dir: populate_exports_dir,
    }
  end

  desc "Import posts from the exports (COUNT, RANGE, QUERY, MEDIA=placeholder|none, MEDIA_THREADS, REINDEX) or the live API (SOURCE=api, SEARCH)"
  task posts: :environment do
    populate_prepare
    if ENV.fetch("SOURCE", "export") == "api"
      Populate::ApiPosts.new(count: populate_int("COUNT", 100), search: ENV.fetch("SEARCH", Populate::ApiPosts::DEFAULT_SEARCH), **populate_common).call
    else
      Populate::Posts.new(**populate_post_options).call
    end
  end

  desc "Write placeholder media for imported posts that have none (COUNT, FORCE, MEDIA_THREADS)"
  task media: :environment do
    populate_prepare
    storage = Danbooru.config.storage_manager
    scope = Post.where.not(file_ext: "swf").order(id: :desc).limit(populate_int("COUNT", 1000))
    ids = scope.filter_map { |post| post.id if ENV["FORCE"].to_s.truthy? || !File.exist?(storage.post_file_path(post, :original)) }
    Populate::Media::Placeholder.new(post_ids: ids, threads: populate_int("MEDIA_THREADS", Etc.nprocessors.clamp(2, 16)), force: ENV["FORCE"].to_s.truthy?).call
  end

  desc "Bulk-index posts and post versions into OpenSearch (FROM, TO)"
  task reindex: :environment do
    populate_prepare
    bounds = { from: ENV["FROM"].presence&.to_i, to: ENV["TO"].presence&.to_i }.compact
    puts "* Indexing posts"
    Post.document_store.import(**bounds)
    puts "* Indexing post versions"
    PostVersion.document_store.import(**bounds)
    Post.document_store.refresh_index!
    PostVersion.document_store.refresh_index!
  end

  # Export-backed importers: whole tables, production ids, no media involved.
  { tags: :Tags, wiki: :WikiPages, artists: :Artists, burs: :BulkUpdateRequests }.each do |name, generator|
    desc "Import #{name} from the exports (EXPORTS_DIR)"
    task name => :environment do
      populate_prepare
      Populate.const_get(generator).new(dir: populate_exports_dir).call
    end
  end

  desc "Assign random post avatars to users without one"
  task avatars: :environment do
    populate_prepare
    Populate::Avatars.new(users: User.where(avatar_id: nil).limit(populate_int("COUNT", 10)).order("random()").to_a).call
  end

  desc "Generate search trend rows (DAYS, HOURS, TAGS)"
  task trends: :environment do
    populate_prepare
    Populate::SearchTrends.new(
      days: populate_int("DAYS", 7),
      hours: populate_int("HOURS", 48),
      tags_count: populate_int("TAGS", 100),
      hourly_tags_count: [populate_int("TAGS", 50), 50].min,
    ).call
  end

  desc "Generate a full set of development data (#{populate_all_defaults.keys.join(', ')})"
  task all: :environment do
    populate_prepare
    counts = populate_all_defaults.to_h { |name, _| [name, populate_int(name, 0)] }
    if counts.values.sum == 0
      puts "DEFAULTS"
      counts = populate_all_defaults
    end
    common = populate_common
    password = ENV.fetch("PASSWORD", Populate::DEFAULT_PASSWORD)

    puts "Populating the Database"
    users = Populate::Users.new(count: counts["USERS"], password: password, **common).call
    if ENV.fetch("SOURCE", "export") == "api"
      posts = Populate::ApiPosts.new(count: counts["POSTS"], users: users, **common).call
      Populate::ApiPosts.new(count: counts["FURIDS"], search: "furid_(e621)", **common).call
    else
      post_options = populate_post_options
      Populate::Posts.new(**post_options, count: counts["POSTS"]).call
      Populate::Posts.new(**post_options, count: counts["FURIDS"], query: "furid_(e621)").call
      posts = Post.order(id: :desc).limit(counts["POSTS"]).to_a
    end
    Populate::Avatars.new(users: users, posts: posts).call

    comments = Populate::Comments.new(count: counts["COMMENTS"], users: users, **common).call
    Populate::Favorites.new(count: counts["FAVORITES"], users: users, **common).call
    Populate::Forums.new(count: counts["FORUMS"], users: users, **common).call
    Populate::PostVotes.new(count: counts["POSTVOTES"], users: users, posts: posts, **common).call
    Populate::CommentVotes.new(count: counts["COMVOTES"], users: users, comments: comments, **common).call
    Populate::Pools.new(count: counts["POOLS"], posts: posts, **common).call
    Populate::Dmails.new(count: counts["DM"], **common).call

    Populate::SearchTrends.new(days: counts["TRENDS"], hours: counts["TRENDS_HOURS"]).call
  end
end
