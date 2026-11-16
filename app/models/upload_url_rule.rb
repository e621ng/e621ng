# frozen_string_literal: true

# Staff-editable rules matched against direct upload URLs. A match either recommends a
# better URL or blocks the upload. A guard against honest mistakes, not a security control.
class UploadUrlRule < ApplicationRecord
  # Raised when a rule cannot be evaluated. Callers refuse the upload: a broken rule is fixed, not skipped.
  class EvaluationError < StandardError
    attr_reader :label

    def initialize(label, message = "upload URL rule '#{label}' failed")
      @label = label
      super(message)
    end
  end

  # An http(s) URL that cannot be canonicalized, so no rule can be checked against it.
  # Refused, or padding a URL past MAX_URL_LENGTH would slip it past every block rule.
  class UncheckableUrlError < EvaluationError
    def initialize
      super(nil, "upload URL cannot be checked against the rules")
    end
  end

  Result = Struct.new(:handling, :label, :message, :suggested_url, :canonical_url, keyword_init: true) do
    def block?
      handling == "block"
    end
  end

  HANDLINGS = %w[recommend block].freeze
  CACHE_KEY = "upload_url_rules"
  MAX_URL_LENGTH = 2_000
  MATCH_TIMEOUT = 0.1 # seconds, per rule

  belongs_to_creator
  belongs_to_updater

  validates :label, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false }
  validates :pattern, presence: true, length: { maximum: 500 }
  validates :replacement, length: { maximum: 500 }
  validates :message, length: { maximum: 500 }
  validates :handling, inclusion: { in: HANDLINGS }
  validate :validate_pattern
  validate :validate_replacement

  after_create do |rec|
    ModAction.log(:upload_url_rule_create, rec.mod_action_values)
  end
  after_update do |rec|
    previous = {
      old_label: rec.label_before_last_save,
      old_pattern: rec.pattern_before_last_save,
      old_replacement: rec.replacement_before_last_save,
      old_handling: rec.handling_before_last_save,
    }
    ModAction.log(:upload_url_rule_update, rec.mod_action_values.merge(previous))
  end
  after_destroy do |rec|
    ModAction.log(:upload_url_rule_delete, rec.mod_action_values)
  end
  # after_commit, not after_save: a concurrent request must not refill the cache with pre-commit rows.
  after_commit { |rec| rec.class.clear_cache }

  scope :enabled, -> { where(enabled: true) }

  def mod_action_values
    { label: label, pattern: pattern, replacement: replacement, handling: handling, message: message, enabled: enabled }
  end

  # Applies this rule alone (saved or not) to a URL. Returns a Result, or nil when it does not match.
  def apply(url)
    canonical = self.class.canonicalize(url)
    return nil if canonical.nil?

    matched, suggested = self.class.match(attributes.slice("label", "pattern", "replacement"), canonical)
    return nil unless matched
    Result.new(handling: handling, label: label, message: message, suggested_url: suggested, canonical_url: canonical)
  end

  module EvaluationMethods
    def clear_cache
      Cache.delete(CACHE_KEY)
    end

    def cached_rules
      Cache.fetch(CACHE_KEY, expires_in: 1.minute) do
        enabled.order(:id).map { |rule| rule.attributes.slice("id", "label", "pattern", "replacement", "message", "handling") }
      end
    end

    # The form rules are written against: free variations of the same URL collapse to one string.
    def canonicalize(url)
      url = url.to_s.strip
      return nil if url.blank? || url.length > MAX_URL_LENGTH || !url.match?(%r{\Ahttps?://}i)

      uri = Addressable::URI.parse(url.unicode_normalize(:nfc)).normalize
      return nil if uri.host.blank?

      uri.userinfo = nil
      uri.fragment = nil
      uri.host = uri.host.chomp(".")
      uri.path = uri.path.gsub(%r{/{2,}}, "/")
      if uri.query.present?
        uri.query = uri.query.split("&").reject(&:empty?).sort_by.with_index { |pair, index| [pair.split("=", 2).first, index] }.join("&")
      else
        uri.query = nil
      end
      uri.to_s
    rescue Addressable::URI::InvalidURIError, ArgumentError, Encoding::CompatibilityError
      nil
    end

    # First matching block rule, else first matching recommend rule, in id order. Every rule is
    # run until a block is found, so a broken rule fails loudly whatever precedes it.
    def evaluate(url)
      canonical = canonicalize(url)
      if canonical.nil?
        raise UncheckableUrlError if url.to_s.scrub.strip.match?(%r{\Ahttps?://}i) && cached_rules.any? { |rule| rule["handling"] == "block" }
        return nil
      end

      recommended = nil
      cached_rules.each do |rule|
        matched, suggested = match(rule, canonical)
        next unless matched

        result = Result.new(handling: rule["handling"], label: rule["label"], message: rule["message"], suggested_url: suggested, canonical_url: canonical)
        return result if result.block?
        recommended ||= result
      end
      recommended
    end

    def block_message(result)
      text = "is not allowed: #{result.label}."
      text += " #{result.message}" if result.message.present?
      text += " Use #{result.suggested_url} instead." if result.suggested_url
      text
    end

    def failure_message(error)
      return "could not be checked: it is not a valid URL or is longer than #{MAX_URL_LENGTH} characters." if error.is_a?(UncheckableUrlError)
      "could not be checked: rule '#{error.label}' failed. Please report this to staff."
    end

    # => [matched, suggested_url]
    def match(rule, canonical)
      regexp = Regexp.new(rule["pattern"], Regexp::IGNORECASE, timeout: MATCH_TIMEOUT)
      return [false, nil] unless regexp.match?(canonical)
      return [true, nil] if rule["replacement"].blank?

      suggested = canonical.sub(regexp, rule["replacement"])
      [true, suggested == canonical ? nil : suggested]
    rescue RegexpError, Regexp::TimeoutError => e # rubocop:disable Lint/ShadowedException
      Rails.logger.error("UploadUrlRule: rule #{rule['id'].inspect} '#{rule['label']}' failed on #{canonical.inspect}: #{e.class}: #{e.message}")
      raise EvaluationError, rule["label"]
    end
  end

  module SearchMethods
    def default_order
      order(:id)
    end

    def search(params)
      q = super

      q = q.where("label ILIKE ?", params[:label].to_escaped_for_sql_like) if params[:label].present?
      q = q.where("pattern ILIKE ?", params[:pattern].to_escaped_for_sql_like) if params[:pattern].present?
      q = q.where(handling: params[:handling]) if params[:handling].present?
      q = q.where(enabled: params[:enabled].to_s.truthy?) if params[:enabled].present?

      case params[:order]
      when "label"
        q.order("upload_url_rules.label")
      when "updated_at"
        q.order("upload_url_rules.updated_at desc")
      else
        q.apply_basic_order(params)
      end
    end
  end

  extend EvaluationMethods
  extend SearchMethods

  private

  def validate_pattern
    return if pattern.blank?

    regexp = Regexp.new(pattern, Regexp::IGNORECASE, timeout: 0.5)
    regexp.match?("https://#{'a' * 100}.example/#{'a' * 100}\u0000")
    errors.add(:pattern, "must not match an empty string") if regexp.match?("")
  rescue Regexp::TimeoutError
    errors.add(:pattern, "causes catastrophic backtracking and cannot be used")
  rescue RegexpError => e
    errors.add(:pattern, "is invalid: #{e.message}")
  end

  def validate_replacement
    return if replacement.blank? || pattern.blank?

    # The alternation with nothing makes the pattern match "", exposing its groups.
    groups = Regexp.new("#{pattern}|").match("")
    replacement.scan(/\\(?:(\d)|k<(\w+)>)/) do |number, name|
      if number && number.to_i > groups.captures.size
        errors.add(:replacement, "refers to group \\#{number}, which the pattern does not have")
      elsif name && groups.names.exclude?(name)
        errors.add(:replacement, "refers to group '#{name}', which the pattern does not have")
      end
    end
  rescue RegexpError
    # Reported by validate_pattern.
  end
end
