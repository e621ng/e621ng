# frozen_string_literal: true

module Populate
  # Placeholder accounts for user ids referenced by imported rows, created with their production ids.
  class StubUsers < Base
    BATCH_SIZE = 1000

    def call
      ids = options.fetch(:ids).map(&:to_i).uniq.sort
      return 0 if ids.empty?

      password_hash = User.bcrypt(options.fetch(:password, DEFAULT_PASSWORD))
      now = Time.current
      created = 0

      ids.each_slice(BATCH_SIZE) do |batch|
        missing = batch - User.where(id: batch).pluck(:id)
        next if missing.empty?

        rows = missing.map do |id|
          {
            id: id,
            name: "user_#{id}",
            password_hash: "",
            bcrypt_password_hash: password_hash,
            email: "user_#{id}@e621.local",
            created_at: now,
            updated_at: now,
            last_ip_addr: LOCAL_IP,
          }
        end
        result = User.insert_all(rows, returning: %i[id]) # skips rows that collide on id or name
        inserted = result.rows.flatten
        UserStatus.insert_all(inserted.map { |id| { user_id: id, created_at: now, updated_at: now } }) if inserted.any?
        created += inserted.size
      end

      Exports.bump_sequence!("users") if created > 0
      created
    end
  end
end
