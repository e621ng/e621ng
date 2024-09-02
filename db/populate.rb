# frozen_string_literal: true

# This script populates the database with random data for testing or development purposes.
# Usage: docker exec -it e621ng-e621-1 /app/bin/populate

require "faker"

# Environmental variables that govern how much content to generate
presets = {
  users: ENV.fetch("USERS", 0).to_i,
  posts: ENV.fetch("POSTS", 0).to_i,
  comments: ENV.fetch("COMMENTS", 0).to_i,
  favorites: ENV.fetch("FAVORITES", 0).to_i,
  forums: ENV.fetch("FORUMS", 0).to_i,
  postvotes: ENV.fetch("POSTVOTES", 0).to_i,
  pools: ENV.fetch("POOLS", 0).to_i,
}
if presets.values.sum == 0
  puts "DEFAULTS"
  presets = {
    users: 10,
    posts: 100,
    comments: 100,
    favorites: 100,
    forums: 100,
    postvotes: 100,
    pools: 100,
  }
end

USERS     = presets[:users]
POSTS     = presets[:posts]
COMMENTS  = presets[:comments]
FAVORITES = presets[:favorites]
FORUMS    = presets[:forums]
POSTVOTES = presets[:postvotes]
POOLS     = presets[:pools]

DISTRIBUTION = ENV.fetch("DISTRIBUTION", 10).to_i
DEFAULT_PASSWORD = ENV.fetch("PASSWORD", "qwerty")

CurrentUser.user = User.system

def api_request(path)
  response = Faraday.get("https://e621.net#{path}", nil, user_agent: "e621ng/seeding")
  JSON.parse(response.body)
end

def populate_users(number, password: DEFAULT_PASSWORD)
  return [] unless number > 0
  puts "* Creating #{number} users\n  This may take some time."

  output = []

  number.times do
    user_name = generate_username
    puts "  - #{user_name}"
    user_obj = User.create do |user|
      user.name = user_name
      user.password = password
      user.password_confirmation = password
      user.email = "#{user_name}@e621.local"
      user.level = User::Levels::MEMBER
      user.created_at = Faker::Date.between(from: "2007-02-10", to: 2.weeks.ago)

      user.profile_about = Faker::Hipster.paragraph_by_chars(characters: rand(100..2_000), supplemental: false) if Faker::Boolean.boolean(true_ratio: 0.2)
      user.profile_artinfo = Faker::Hipster.paragraph_by_chars(characters: rand(100..2_000), supplemental: false) if Faker::Boolean.boolean(true_ratio: 0.2)
    end

    if user_obj.errors.empty?
      output << user_obj
      puts "    user ##{user_obj.id}"
    else
      puts "    error: #{user_obj.errors.full_messages.join('; ')}"
    end
  end

  output
end

def generate_username
  loop do
    @username = [
      Faker::Adjective.positive.split.each(&:capitalize!),
      Faker::Creature::Animal.name.split.each(&:capitalize!),
    ].concat.join("_")

    next unless @username.length >= 3 && @username.length <= 20
    next unless User.find_by(name: @username).nil?
    break
  end

  @username
end

def populate_posts(number, users: [], batch_size: 320)
  return [] unless number > 0
  puts "* Creating #{number} posts"

  admin = User.find(1)
  users = User.where("users.created_at < ?", 7.days.ago).limit(DISTRIBUTION).order("random()") if users.empty?
  output = []

  # Generate posts in batches of 200 (by default)
  number.times.each_slice(batch_size).map(&:size).each do |count|
    posts = api_request("/posts.json?tags=rating:s+order:random+score:>250+-grandfathered_content&limit=#{count}")["posts"]

    posts.each do |post|
      post["tags"].each do |category, tags|
        Tag.find_or_create_by_name_list(tags.map { |tag| "#{category}:#{tag}" })
      end

      CurrentUser.user = users.sample # Stupid, but I can't be bothered
      CurrentUser.user = users.sample unless CurrentUser.user.can_upload_with_reason
      puts "  - #{CurrentUser.user.name} : #{post['file']['url']}"

      Post.transaction do
        service = UploadService.new(generate_upload(post))
        @upload = service.start!
      end

      if @upload.invalid? || @upload.post.nil?
        puts "    #{@upload.errors.full_messages.join('; ')}"
      else
        puts "    post: ##{@upload.post.id}"
        CurrentUser.scoped(admin) do
          @upload.post.approve!
        end
        output << @upload.post
      end
    end
  end

  output
end

def generate_upload(post)
  {
    uploader: CurrentUser.user,
    uploader_ip_addr: "127.0.0.1",
    direct_url: post["file"]["url"],
    tag_string: post["tags"].values.flatten.join(" "),
    source: post["sources"].join("\n"),
    description: post["description"],
    rating: post["rating"],
  }
end

def fill_avatars(users = [], posts = [])
  return if users.empty?
  puts "* Filling in #{users.size} avatars"

  posts = Post.limit(users.size).order("random()") if posts.empty?
  puts posts

  users.each do |user|
    post = posts.sample
    puts "post: #{post}"
    puts "  - #{user.name} : ##{post.id}"
    user.update({ avatar_id: post.id })
  end
end

def populate_comments(number, users: [])
  return unless number > 0
  puts "* Creating #{number} comments"

  users = User.where("users.created_at < ?", 14.days.ago).limit(DISTRIBUTION).order("random()") if users.empty?
  posts = Post.limit(DISTRIBUTION).order("random()")

  number.times do
    post = posts.sample
    CurrentUser.user = users.sample

    comment_obj = Comment.create do |comment|
      comment.creator = CurrentUser.user
      comment.updater = CurrentUser.user
      comment.post = post
      comment.body = Faker::Hipster.paragraph_by_chars(characters: rand(100..2_000), supplemental: false)
      comment.creator_ip_addr = "127.0.0.1"
    end

    puts "  - ##{comment_obj.id} by #{CurrentUser.user.name}"
  end
end

def populate_favorites(number, users: [])
  return unless number > 0
  puts "* Creating #{number} favorites"

  users = User.limit(DISTRIBUTION).order("random()") if users.empty?

  number.times do |index|
    CurrentUser.user = users[index % DISTRIBUTION]
    post = Post.order("random()").first
    puts "  - ##{post.id} faved by #{CurrentUser.user.name}"

    begin
      Favorite.create do |fav|
        fav.user = CurrentUser.user
        fav.post = post
      end
    rescue StandardError
      puts "    Favorite already exists"
    end
  end
end

def populate_forums(number, users: [])
  return unless number > 0
  number -= 1 # Accounts for the first post in the thread
  puts "* Creating a topic with #{number} replies"

  users = User.where("users.created_at < ?", 14.days.ago).limit(DISTRIBUTION).order("random()") if users.empty?

  category = ForumCategory.find_or_create_by!(name: "General") do |cat|
    cat.can_view = 0
  end

  CurrentUser.user = users.sample
  CurrentUser.ip_addr = "127.0.0.1"
  forum_topic = ForumTopic.create do |topic|
    topic.creator = CurrentUser.user
    topic.creator_ip_addr = "127.0.0.1"
    topic.title = Faker::Lorem.sentence(word_count: 3, supplemental: true, random_words_to_add: 4)
    topic.category = category
    topic.original_post_attributes = {
      creator: CurrentUser.user,
      body: Faker::Lorem.paragraphs.join("\n\n"),
    }
  end

  puts "  topic ##{forum_topic.id} by #{CurrentUser.user.name}"

  unless forum_topic.valid?
    puts "  #{forum_topic.errors.full_messages.join('; ')}"
  end

  number.times do
    CurrentUser.user = users.sample

    forum_post = ForumPost.create do |post|
      post.creator = CurrentUser.user
      post.topic_id = forum_topic.id
      post.body = Faker::Hipster.paragraph_by_chars(characters: rand(100..2_000), supplemental: false)
    end

    puts "  - #{CurrentUser.user.name} | forum post ##{forum_post.id}"

    unless forum_post.valid?
      puts "    #{forum_post.errors.full_messages.join('; ')}"
    end
  end
end

def populate_post_votes(number, users: [], posts: [])
  return unless number > 0
  puts "* Generating votes"

  users = User.where("users.created_at < ?", 14.days.ago).limit(DISTRIBUTION).order("random()") if users.empty?
  posts = Post.limit(100).order("random()") if posts.empty?

  number.times do
    CurrentUser.user = users.sample
    post = posts.sample

    vote = VoteManager.vote!(
      user: CurrentUser.user,
      post: post,
      score: Faker::Boolean.boolean(true_ratio: 0.2) ? -1 : 1,
    )

    if vote == :need_unvote
      puts "    error: #{vote}"
      next
    else
      puts "    vote ##{vote.id} on post ##{post.id}"
    end
  end
end

def populate_pools(number, posts: [])
  return unless number > 0
  puts "* Generating pools"

  CurrentUser.user = User.find(1)
  posts = Post.limit(number).order("random()") if posts.empty?

  pool_obj = Pool.create do |pool|
    pool.name = Faker::Lorem.sentence
    pool.category = "collection"
    pool.post_ids = posts.pluck(:id)
  end
  puts pool_obj

  if pool_obj.errors.empty?
    puts "  pool ##{pool_obj.id}"
  else
    puts "    error: #{pool_obj.errors.full_messages.join('; ')}"
  end
end

puts "Populating the Database"
CurrentUser.user = User.find(1)
CurrentUser.ip_addr = "127.0.0.1"

users = populate_users(USERS)
posts = populate_posts(POSTS, users: users)
fill_avatars(users, posts)

populate_comments(COMMENTS, users: users)
populate_favorites(FAVORITES, users: users)
populate_forums(FORUMS, users: users)
populate_post_votes(POSTVOTES, users: users, posts: posts)
populate_pools(POOLS, posts: posts)
