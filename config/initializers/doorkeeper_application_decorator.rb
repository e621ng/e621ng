# frozen_string_literal: true

module DoorkeeperApplicationDecorator
  module Search
    def paginate(page, options = {})
      extending(Danbooru::Paginator::ActiveRecordExtension).paginate(page, options)
    end

    def search(params = {})
      q = all
      q = q.where("lower(oauth_applications.name) LIKE ?", "%#{params[:name].to_s.downcase}%") if params[:name].present?
      if params[:owner_name].present?
        owner = User.find_by("lower(name) = ?", params[:owner_name].downcase)
        q = q.where(owner_type: "User", owner_id: owner&.id)
      end
      q
    end
  end

  module Authorization
    def authorization_denial_reason_for(resource_owner)
      if owner.is_a?(User) && owner.is_restricted?
        "This application's owner is no longer in good standing."
      elsif owner.is_a?(User) && !owner.can_manage_oauth_applications?
        "This application is no longer available."
      elsif resource_owner&.is_restricted?
        "Your account is restricted."
      elsif minimum_user_level.to_i > 0 && resource_owner&.level.to_i < minimum_user_level.to_i
        "You do not have access to this application."
      end
    end
  end
end

# to_prepare runs after Doorkeeper has loaded its model in both dev and prod.
Rails.application.config.to_prepare do
  Doorkeeper::Application.extend(DoorkeeperApplicationDecorator::Search)
  Doorkeeper::Application.include(DoorkeeperApplicationDecorator::Authorization)

  Doorkeeper::Application.class_eval do
    attr_accessor :authorization_denial_reason

    validates :description, length: { maximum: 500 }, allow_blank: true
    validates :homepage_url, length: { maximum: 2048 }, allow_blank: true
    validates :homepage_url,
              format: { with: %r{\Ahttps?://}, message: "must start with http:// or https://" },
              if: -> { homepage_url.present? }
    validates :minimum_user_level,
              inclusion: { in: ->(_) { [0] + User.level_hash.values } }

    validate :enforce_per_owner_application_limit, on: :create

    def enforce_per_owner_application_limit
      return unless owner.is_a?(User)
      limit = owner.oauth_application_limit
      return if owner.oauth_applications.count < limit
      errors.add(:base, "OAuth application limit reached (max #{limit})")
    end
  end
end
