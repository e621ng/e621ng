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
      posts: [:ApiPosts, 100, -> {
        source = ENV.fetch("SOURCE", "api")
        raise ArgumentError, "SOURCE=#{source} is not available yet; only SOURCE=api" unless source == "api"
        { search: ENV.fetch("SEARCH", Populate::ApiPosts::DEFAULT_SEARCH) }
      },],
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
    posts = Populate::ApiPosts.new(count: counts["POSTS"], users: users, **common).call
    Populate::Avatars.new(users: users, posts: posts).call
    Populate::ApiPosts.new(count: counts["FURIDS"], search: "furid_(e621)", **common).call

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
