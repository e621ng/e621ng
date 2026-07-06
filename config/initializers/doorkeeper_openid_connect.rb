# frozen_string_literal: true

require Rails.root.join("app/logical/oidc_signing_key")

Doorkeeper::OpenidConnect.configure do
  issuer do |_resource_owner, _application|
    scheme = Rails.env.production? ? "https" : "http"
    "#{scheme}://#{Danbooru.config.hostname}"
  end

  signing_key -> { OidcSigningKey.pem }

  expiration Doorkeeper.config.access_token_expires_in

  subject_types_supported [:public]

  resource_owner_from_access_token do |access_token|
    User.find_by(id: access_token.resource_owner_id)
  end

  # Block is called without controller context during id_token issuance, so it
  # must use a resource_owner attribute. Set by SessionCreator and SessionLoader.
  auth_time_from_resource_owner do |resource_owner|
    resource_owner.last_logged_in_at
  end

  reauthenticate_resource_owner do |_resource_owner, return_to|
    session[:url] = return_to
    redirect_to(new_session_path)
  end

  subject do |resource_owner, _application|
    resource_owner.id
  end

  protocol { Rails.env.production? ? :https : :http }

  claims do
    normal_claim :preferred_username do |resource_owner|
      resource_owner.name
    end

    normal_claim :name do |resource_owner|
      resource_owner.name
    end

    normal_claim :picture do |resource_owner|
      next nil unless resource_owner.avatar_id

      safe_mode = Danbooru.config.safe_mode? || resource_owner.enable_safe_mode?
      avatar_post = Post.find_by(id: resource_owner.avatar_id) if safe_mode || !resource_owner.has_cropped_avatar?
      next nil if safe_mode && avatar_post&.rating != "s"

      if resource_owner.has_cropped_avatar?
        url = Danbooru.config.storage_manager.avatar_url(resource_owner.id, "jpg")
        "#{url}?t=#{resource_owner.updated_at.to_i}"
      else
        avatar_post&.preview_file_url
      end
    end

    normal_claim :updated_at do |resource_owner|
      resource_owner.updated_at.to_i
    end

    normal_claim :e621_level do |resource_owner|
      resource_owner.level
    end

    normal_claim :e621_level_string do |resource_owner|
      resource_owner.level_string
    end

    normal_claim :e621_avatar_id do |resource_owner|
      resource_owner.avatar_id
    end

    normal_claim :e621_permissions do |resource_owner|
      flags = %w[
        can_approve_posts can_upload_free
        is_bd_staff is_bd_auditor
        can_view_staff_notes can_handle_takedowns can_edit_avoid_posting_entries
      ] + UserLevel::ROLES.map { |role| "is_#{role}" }
      flags.select { |flag| resource_owner.send("#{flag}?") }
    end

    normal_claim :email do |resource_owner|
      resource_owner.email
    end

    normal_claim :email_verified do |resource_owner|
      # email_verification_key.nil? is also true when email is blank.
      resource_owner.email.present? && resource_owner.email_verification_key.nil?
    end
  end
end
