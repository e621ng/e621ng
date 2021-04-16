module UserWarnable
  extend ActiveSupport::Concern

  WARNING_TYPES = {
      'warning' => 1,
      'record' => 2,
      'ban' => 3,
      'unmark' => nil
  }

  included do
    scope :user_warned, -> { where('warning_type IS NOT NULL') }
    validates :warning_type, inclusion: { :in => [1, 2, 3, nil] }
  end

  def user_warned!(type, user=CurrentUser.id)
    unless WARNING_TYPES.has_key?(type)
      errors.add(:warning_type, 'invalid warning type')
      return
    end
    update({warning_type: WARNING_TYPES[type], warning_user_id: user})
  end

  def remove_user_warning!
    update_columns({warning_type: nil, warning_user_id: nil})
  end

  def was_warned?
    !warning_type.nil?
  end

  def warning_type_string
    case warning_type
    when 1
      "User received a warning for the contents of this message."
    when 2
      "User received a record for the contents of this message."
    when 3
      "User was banned for the contents of this message."
    else
      "[This is a bug with the website. Woo!]"
    end
  end
end
