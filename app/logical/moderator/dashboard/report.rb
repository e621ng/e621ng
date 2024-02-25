# frozen_string_literal: true

module Moderator
  module Dashboard
    class Report
      attr_reader :min_date, :max_level

      def initialize(min_date, max_level)
        @min_date = min_date.present? ? min_date.to_date : 1.week.ago
        @max_level = max_level.present? ? max_level.to_i : User::Levels::MEMBER
      end

      def artists
        ApplicationRecord.without_timeout do
          Queries::Artist.all(min_date, max_level)
        end
      end

      def comments
        ApplicationRecord.without_timeout do
          Queries::Comment.all(min_date, max_level)
        end
      end

      def mod_actions
        ApplicationRecord.without_timeout do
          Queries::ModAction.all
        end
      end

      def notes
        ApplicationRecord.without_timeout do
          Queries::Note.all(min_date, max_level)
        end
      end

      def tags
        Queries::Tag.all(min_date, max_level)
      end

      def posts
        ApplicationRecord.without_timeout do
          Queries::Upload.all(min_date, max_level)
        end
      end

      def user_feedbacks
        ApplicationRecord.without_timeout do
          Queries::UserFeedback.all
        end
      end

      def wiki_pages
        ApplicationRecord.without_timeout do
          Queries::WikiPage.all(min_date, max_level)
        end
      end
    end
  end
end
