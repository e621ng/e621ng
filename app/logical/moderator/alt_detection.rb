# frozen_string_literal: true

module Moderator
  module AltDetection
    def self.enabled?
      Setting.alt_detection_enabled?
    end

    def self.enabled=(state)
      Setting.alt_detection_enabled = state == "1"
    end

    def self.cgnat_threshold
      Setting.alt_cgnat_threshold
    end

    def self.cgnat_threshold=(value)
      Setting.alt_cgnat_threshold = value
    end

    def self.strong_threshold
      Setting.alt_strong_threshold
    end

    def self.strong_threshold=(value)
      Setting.alt_strong_threshold = value
    end

    def self.possible_threshold
      Setting.alt_possible_threshold
    end

    def self.possible_threshold=(value)
      Setting.alt_possible_threshold = value
    end

    def self.weak_floor
      Setting.alt_weak_floor
    end

    def self.weak_floor=(value)
      Setting.alt_weak_floor = value
    end

    def self.lookups_per_minute
      Setting.alt_lookups_per_minute
    end

    def self.lookups_per_minute=(value)
      Setting.alt_lookups_per_minute = value
    end

    def self.score_to_badge(score)
      score = score.to_f
      return :strong   if score >= strong_threshold
      return :possible if score >= possible_threshold
      return :weak     if score >  weak_floor
      nil
    end
  end
end
