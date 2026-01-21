# frozen_string_literal: true

User.without_timeout do # rubocop:disable Metrics/BlockLength
  fixed = 0
  invalidated = 0

  # Create validator instance once for efficiency
  email_validator = EmailAddressValidator.new(attributes: [:email])

  User.in_batches.each_with_index do |group, index|
    group.each do |user|
      next if user.email.blank? || user.email_verification_key.present?

      original_email = user.email
      user.normalize_email_address

      # Run email validation directly without triggering full model validation
      user.errors.clear
      email_validator.validate_each(user, :email, user.email)

      if user.errors[:email].empty?
        if user.email == original_email
          next
        end
        begin
          user.save!
          puts "  Fixed email to '#{user.email}'"
          fixed += 1
        rescue ActiveRecord::RecordInvalid
          user.update_column(:email_verification_key, "1")
          invalidated += 1
        end
      else
        user.update_column(:email_verification_key, "1")
        invalidated += 1
      end
    end

    puts "Batch #{index}: fixed #{fixed}, invalidated #{invalidated}"
  end

  puts "Final totals: fixed #{fixed}, invalidated #{invalidated}"
end
