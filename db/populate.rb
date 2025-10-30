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
  commentvotes: ENV.fetch("COMVOTES", 0).to_i,
  pools: ENV.fetch("POOLS", 0).to_i,
  furids: ENV.fetch("FURIDS", 0).to_i,
  dmails: ENV.fetch("DM", 0).to_i,
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
    commentvotes: 100,
    pools: 100,
    furids: 0,
    dmails: 0,
  }
end

USERS     = presets[:users]
POSTS     = presets[:posts]
COMMENTS  = presets[:comments]
FAVORITES = presets[:favorites]
FORUMS    = presets[:forums]
POSTVOTES = presets[:postvotes]
COMVOTES  = presets[:commentvotes]
POOLS     = presets[:pools]
FURIDS    = presets[:furids]
DMAILS    = presets[:dmails]

DISTRIBUTION = ENV.fetch("DISTRIBUTION", 10).to_i
DEFAULT_PASSWORD = ENV.fetch("PASSWORD", "hexerade")

CurrentUser.user = User.system

def api_request(path)
  response = Faraday.get("https://e621.net#{path}", nil, user_agent: "e621ng/seeding")
  JSON.parse(response.body)
end

def populate_users(number, password: DEFAULT_PASSWORD)
  return [] unless number > 0
  puts "* Creating #{number} users\n  This may take some time."

  output = []
  batch_size = 100

  encrypted_password = User.bcrypt(password)
  existing_names = Set.new(User.pluck(:name))
  usernames = []

  puts "  Generating #{number} unique usernames..."
  while usernames.length < number
    candidate = generate_username_candidate
    next if existing_names.include?(candidate) || usernames.include?(candidate)
    usernames << candidate
    existing_names << candidate # Track locally to avoid duplicates in this batch
  end

  # Process users in batches
  usernames.each_slice(batch_size) do |batch_usernames| # rubocop:disable Metrics/BlockLength
    puts "  Creating batch of #{batch_usernames.size} users..."

    batch_users = batch_usernames.map do |user_name|
      created_at = Faker::Date.between(from: "2007-02-10", to: 2.weeks.ago)
      has_about = Faker::Boolean.boolean(true_ratio: 0.2)
      has_artinfo = Faker::Boolean.boolean(true_ratio: 0.2)

      {
        name: user_name,
        password_hash: "", # Required NOT NULL, but should be empty for bcrypt
        bcrypt_password_hash: encrypted_password,
        email: "#{user_name}@e621.local",
        created_at: created_at,
        updated_at: created_at,
        last_ip_addr: "127.0.0.1",
        profile_about: has_about ? Faker::Hipster.paragraph_by_chars(characters: rand(100..2_000), supplemental: false) : "",
        profile_artinfo: has_artinfo ? Faker::Hipster.paragraph_by_chars(characters: rand(100..2_000), supplemental: false) : "",
      }
    end

    begin
      result = User.insert_all(batch_users, returning: %i[id name])

      user_status_records = result.rows.map do |row|
        user_id = row[0]
        now = Time.current
        {
          user_id: user_id,
          created_at: now,
          updated_at: now,
        }
      end

      UserStatus.insert_all(user_status_records) if user_status_records.any?

      result.rows.each do |row|
        user = User.find(row[0]) # Load the full user object from database
        output << user
        puts "    user ##{row[0]} (#{row[1]})"
      end
    rescue StandardError => e
      puts "    error in batch: #{e.message}"
      # Fall back to individual creation
      batch_users.each do |user_attrs|
        user = User.create!(user_attrs.except(:password_hash, :bcrypt_password_hash).merge(password: password, password_confirmation: password))
        output << user
        puts "    user ##{user.id} (#{user.name}) - individual"
      rescue StandardError => user_error
        puts "    error: #{user_error.message}"
      end
    end
  end

  output
end

def generate_username
  loop do
    @username = generate_username_candidate
    next unless @username.length >= 3 && @username.length <= 20
    next unless User.find_by(name: @username).nil?
    break
  end

  @username
end

def generate_username_candidate
  [
    Faker::Adjective.positive.split.each(&:capitalize!),
    Faker::Creature::Animal.name.split.each(&:capitalize!),
  ].concat.join("_")
end

def populate_posts(number, search: "order:random+score:>150+-grandfathered_content", users: [], batch_size: 320)
  return [] unless number > 0
  puts "* Creating #{number} posts"

  admin = User.find(1)
  users = User.where("users.created_at < ?", 7.days.ago).limit(DISTRIBUTION).order("random()") if users.empty?
  output = []

  seed = Faker::Number.within(range: 100_000..100_000_000)
  puts "  Seed #{seed}"

  total = 0
  skipped = 0
  page = 1

  while total < number
    posts = api_request("/posts.json?tags=#{search}+-young+-type:swf+randseed:#{seed}&limit=#{batch_size}&page=#{page + 1}")["posts"]
    if posts&.length != batch_size
      puts "  End of Content"
      break
    end

    imported = posts.reject do |post|
      Post.where(md5: post["file"]["md5"]).exists?
    end

    puts "  Page #{page}, skipped #{skipped}"

    imported.each do |post|
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
        puts "    invalid: #{@upload.errors.full_messages.join('; ')}"
      else
        puts "    post: ##{@upload.post.id}"
        CurrentUser.scoped(admin) do
          @upload.post.approve!
        end

        total += 1
        output << @upload.post
      end

      break if total >= number
    end

    page += 1
  end

  puts "  Created #{total}, skipped #{skipped} posts from #{page - 1} pages"

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
  return [] unless number > 0
  puts "* Creating #{number} comments"
  output = []

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
    output << comment_obj if comment_obj.valid?
  end

  output
end

def populate_favorites(number, users: [])
  return unless number > 0
  puts "* Creating #{number} favorites"

  users = User.limit(DISTRIBUTION).order("random()") if users.empty?
  posts = Post.limit([number, 1000].min).order("random()") # Limit posts to avoid too many random queries

  batch_size = 500
  favorites_data = []
  post_fav_updates = Hash.new { |h, k| h[k] = [] } # post_id => [user_ids]

  # Generate all favorite combinations upfront
  puts "  Generating #{number} unique user-post combinations..."

  number.times do |index|
    user = users[index % DISTRIBUTION]
    post = posts.sample

    # Check for duplicates in this batch
    next if favorites_data.any? { |fav| fav[:user_id] == user.id && fav[:post_id] == post.id }

    favorites_data << {
      user_id: user.id,
      post_id: post.id,
      created_at: Time.current,
    }

    post_fav_updates[post.id] << user.id
  end

  puts "  Creating #{favorites_data.size} favorites in batches..."

  # Process favorites in batches
  favorites_data.each_slice(batch_size) do |batch_favorites| # rubocop:disable Metrics/BlockLength
    begin
      # Create favorites in bulk
      if Favorite.respond_to?(:insert_all)
        result = Favorite.insert_all(batch_favorites, returning: %i[id user_id post_id])
        puts "    Created batch of #{result.rows.size} favorites"
      else
        # Fallback for older Rails versions
        batch_favorites.each do |fav_attrs|
          Favorite.create!(fav_attrs)
        end
        puts "    Created batch of #{batch_favorites.size} favorites (individual)"
      end
    rescue StandardError => e
      puts "    Error in batch creation: #{e.message}"
      # Fall back to individual creation with duplicate checking
      batch_favorites.each do |fav_attrs|
        user = User.find(fav_attrs[:user_id])
        post = Post.find(fav_attrs[:post_id])
        FavoriteManager.add!(user: user, post: post)
        puts "    - ##{post.id} faved by #{user.name} (individual)"
      rescue Favorite::Error => fav_error
        puts "    - Error: #{fav_error.message}"
      rescue StandardError => other_error
        puts "    - Error: #{other_error.message}"
      end
      next # Skip bulk post updates for this batch since we used FavoriteManager
    end

    # Update post fav_strings and fav_counts for this batch
    batch_post_ids = batch_favorites.pluck(:post_id).uniq
    batch_post_ids.each do |post_id|
      user_ids = post_fav_updates[post_id]
      next if user_ids.empty?

      post = Post.find(post_id)
      current_fav_string = post.fav_string || ""
      current_fav_parts = current_fav_string.split
      new_fav_parts = user_ids.map { |user_id| "fav:#{user_id}" }
      all_fav_parts = (current_fav_parts + new_fav_parts).uniq

      post.update_columns(
        fav_string: all_fav_parts.join(" "),
        fav_count: all_fav_parts.size,
        updated_at: Time.current,
      )

      puts "    Updated post ##{post_id} fav_string (#{user_ids.size} new favs)"
    end

    # Update user favorite counts
    user_counts = batch_favorites.group_by { |fav| fav[:user_id] }
                                 .transform_values(&:size)

    user_counts.each do |user_id, count|
      UserStatus.where(user_id: user_id).update_all(
        "favorite_count = favorite_count + #{count}",
      )
    end
  end

  puts "  Completed creating favorites"
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
  puts "* Generating post votes"

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

def populate_comment_votes(number, users: [], comments: [])
  return unless number > 0
  puts "* Generating comment votes"

  users = User.where("users.created_at < ?", 14.days.ago).limit(DISTRIBUTION).order("random()") if users.empty?
  comments = Comment.limit(100).order("random()") if comments.empty?

  number.times do
    CurrentUser.user = users.sample
    comment = comments.sample

    if comment.creator_id == CurrentUser.user.id
      puts "    error: can't vote on your own comment"
      next
    elsif comment.is_sticky?
      puts "    error: can't vote on a sticky comment"
      next
    end

    vote = VoteManager.comment_vote!(
      user: CurrentUser.user,
      comment: comment,
      score: Faker::Boolean.boolean(true_ratio: 0.2) ? -1 : 1,
    )

    if vote == :need_unvote
      puts "    error: #{vote}"
      next
    else
      puts "    vote ##{vote.id} on comment ##{comment.id}"
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

def populate_dmails(number)
  return unless number > 0
  puts "* Generating DMs"

  users = User.where("users.created_at < ?", 14.days.ago).limit(100).order("random()")

  number.times do
    sender = users.sample
    recipient = users.sample

    next if sender == recipient

    dm_obj = Dmail.create_split(
      from_id: sender.id,
      to_id: recipient.id,
      title: Faker::Hipster.sentence(word_count: rand(3..10)),
      body: Faker::Hipster.paragraph_by_chars(characters: rand(100..2_000), supplemental: false),
      bypass_limits: true,
    )

    puts "  - DM ##{dm_obj.id} from #{sender.name} to #{recipient.name}"

    unless dm_obj.valid?
      puts "    #{dm_obj.errors.full_messages.join('; ')}"
    end
  end
end

puts "Populating the Database"
CurrentUser.user = User.find(1)
CurrentUser.ip_addr = "127.0.0.1"

users = populate_users(USERS)
posts = populate_posts(POSTS, users: users)
fill_avatars(users, posts)

populate_posts(FURIDS, search: "furid_(e621)") if FURIDS

comments = populate_comments(COMMENTS, users: users)
populate_favorites(FAVORITES, users: users)
populate_forums(FORUMS, users: users)
populate_post_votes(POSTVOTES, users: users, posts: posts)
populate_comment_votes(COMVOTES, users: users, comments: comments)
populate_pools(POOLS, posts: posts)
populate_dmails(DMAILS)
