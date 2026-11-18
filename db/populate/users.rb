# frozen_string_literal: true

module Populate
  class Users < Base
    BATCH_SIZE = 100

    def call
      count = options.fetch(:count, 0)
      password = options.fetch(:password, DEFAULT_PASSWORD)
      return [] unless count > 0
      log "* Creating #{count} users\n  This may take some time."

      output = []
      encrypted_password = User.bcrypt(password)

      log "  Generating #{count} unique usernames..."
      usernames = generate_usernames(count)

      usernames.each_slice(BATCH_SIZE) do |batch_usernames|
        log "  Creating batch of #{batch_usernames.size} users..."
        batch_users = batch_usernames.map { |name| user_attributes(name, encrypted_password) }

        begin
          result = User.insert_all(batch_users, returning: %i[id name])

          now = Time.current
          user_status_records = result.rows.map { |row| { user_id: row[0], created_at: now, updated_at: now } }
          UserStatus.insert_all(user_status_records) if user_status_records.any?

          result.rows.each do |row|
            output << User.find(row[0])
            log "    user ##{row[0]} (#{row[1]})"
          end
        rescue StandardError => e
          log "    error in batch: #{e.message}"
          # Fall back to individual creation
          batch_users.each do |user_attrs|
            user = User.create!(user_attrs.except(:password_hash, :bcrypt_password_hash).merge(password: password, password_confirmation: password))
            output << user
            log "    user ##{user.id} (#{user.name}) - individual"
          rescue StandardError => user_error
            log "    error: #{user_error.message}"
          end
        end
      end

      output
    end

    private

    def generate_usernames(count)
      existing_names = Set.new(User.pluck(:name))
      usernames = []
      while usernames.length < count
        candidate = username_candidate
        next if existing_names.include?(candidate)
        usernames << candidate
        existing_names << candidate
      end
      usernames
    end

    def username_candidate
      [
        Faker::Adjective.positive.split.each(&:capitalize!),
        Faker::Creature::Animal.name.split.each(&:capitalize!),
      ].concat.join("_")
    end

    def user_attributes(name, encrypted_password)
      created_at = Faker::Date.between(from: "2007-02-10", to: 2.weeks.ago)
      has_about = Faker::Boolean.boolean(true_ratio: 0.2)
      has_artinfo = Faker::Boolean.boolean(true_ratio: 0.2)

      {
        name: name,
        password_hash: "", # Required NOT NULL, but should be empty for bcrypt
        bcrypt_password_hash: encrypted_password,
        email: "#{name}@e621.local",
        created_at: created_at,
        updated_at: created_at,
        last_ip_addr: LOCAL_IP,
        profile_about: has_about ? paragraph : "",
        profile_artinfo: has_artinfo ? paragraph : "",
      }
    end
  end
end
