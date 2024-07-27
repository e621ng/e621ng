# frozen_string_literal: true

class BulkUpdateRequestImporter
  class Error < RuntimeError; end
  attr_accessor :text, :forum_id, :creator_id, :creator_ip_addr

  def initialize(text, forum_id, creator = nil, ip_addr = nil)
    @forum_id = forum_id
    @text = text
    @creator_id = creator
    @creator_ip_addr = ip_addr
  end

  def process!(approver = CurrentUser.user)
    tokens = BulkUpdateRequestImporter.tokenize(text)
    execute(tokens, approver)
  end

  def validate!(user)
    tokens = BulkUpdateRequestImporter.tokenize(text)
    validate_annotate(tokens, user)
  end

  def self.tokenize(text)
    text.split(/\r\n|\r|\n/).reject(&:blank?).map do |line|
      line = line.gsub(/[[:space:]]+/, " ").strip

      if line =~ /^(?:create alias|aliasing|alias) (\S+) -> (\S+)( #.*)?$/i
        [:create_alias, $1, $2, $3]

      elsif line =~ /^(?:create implication|implicating|implicate|imply) (\S+) -> (\S+)( #.*)?$/i
        [:create_implication, $1, $2, $3]

      elsif line =~ /^(?:remove alias|unaliasing|unalias) (\S+) -> (\S+)( #.*)?$/i
        [:remove_alias, $1, $2, $3]

      elsif line =~ /^(?:remove implication|unimplicating|unimplicate|unimply) (\S+) -> (\S+)( #.*)?$/i
        [:remove_implication, $1, $2, $3]

      elsif line =~ /^(?:mass update|updating|update|change) (\S+) -> (\S+)( #.*)?$/i
        [:mass_update, $1, $2, $3]

      elsif line =~ /^(?:nuke tag|nuke) (\S+)( #.*)?$/i
        [:nuke_tag, $1, nil, $2]

      elsif line =~ /^category (\S+) -> (#{Tag.categories.regexp})( #.*)?$/i
        [:change_category, $1, $2, $3]

      elsif line.strip.empty?
        # do nothing

      else
        raise Error, "Unparseable line: #{line}"
      end
    end
  end

  def self.untokenize(tokens)
    tokens.map do |token|
      case token[0]
      when :create_alias
        comment = "# #{token[3]}" if token[3].present?
        "alias #{token[1]} -> #{token[2]} #{comment}".strip
      when :create_implication
        comment = "# #{token[3]}" if token[3].present?
        "implicate #{token[1]} -> #{token[2]} #{comment}".strip
      when :remove_alias
        comment = "# missing" if token[3] == false
        "unalias #{token[1]} -> #{token[2]} #{comment}".strip
      when :remove_implication
        comment = "# missing" if token[3] == false
        "unimplicate #{token[1]} -> #{token[2]} #{comment}".strip
      when :change_category
        comment = "# missing" if token[3] == false
        "category #{token[1]} -> #{token[2]} #{comment}".strip
      when :mass_update
        comment = "# missing" if token[3] == false
        "update #{token[1]} -> #{token[2]} #{comment}".strip
      when :nuke_tag
        comment = "# missing" if token[3] == false
        "nuke tag #{token[1]} #{comment}".strip
      else
        raise Error.new("Unknown token to reverse")
      end
    end
  end

  def validate_alias(token)
    tag_alias = TagAlias.duplicate_relevant.find_by(antecedent_name: token[1], consequent_name: token[2])
    if tag_alias.present? && tag_alias.has_transitives
      return [nil, "duplicate of alias ##{tag_alias.id}; has blocking transitive relationships, cannot be applied through BUR"]
    end
    return [nil, "duplicate of alias ##{tag_alias.id}"] unless tag_alias.nil?
    tag_alias = TagAlias.new(forum_topic_id: forum_id, status: "pending", antecedent_name: token[1], consequent_name: token[2])
    unless tag_alias.valid?
      return ["Error: #{tag_alias.errors.full_messages.join("; ")} (create alias #{tag_alias.antecedent_name} -> #{tag_alias.consequent_name})", nil]
    end
    if tag_alias.has_transitives
      return [nil, "has blocking transitive relationships, cannot be applied through BUR"]
    end
    return [nil, nil]
  end

  def validate_implication(token)
    tag_implication = TagImplication.duplicate_relevant.find_by(antecedent_name: token[1], consequent_name: token[2])
    return [nil, "duplicate of implication ##{tag_implication.id}"] unless tag_implication.nil?
    tag_implication = TagImplication.new(forum_topic_id: forum_id, status: "pending", antecedent_name: token[1], consequent_name: token[2])
    unless tag_implication.valid?
      return ["Error: #{tag_implication.errors.full_messages.join("; ")} (create implication #{tag_implication.antecedent_name} -> #{tag_implication.consequent_name})", nil]
    end
    return [nil, nil]
  end

  def validate_annotate(tokens, user)
    errors = []
    annotated = tokens.map do |token|
      case token[0]
      when :create_alias
        output = validate_alias(token)
        errors << output[0] if output[0].present?
        token[3] = output[1]
        token

      when :create_implication
        output = validate_implication(token)
        errors << output[0] if output[0].present?
        token[3] = output[1]
        token

      when :remove_alias
        existing = TagAlias.duplicate_relevant.find_by(antecedent_name: token[1], consequent_name: token[2]).present?
        token[3] = existing
        token

      when :remove_implication
        existing = TagImplication.duplicate_relevant.find_by(antecedent_name: token[1], consequent_name: token[2]).present?
        token[3] = existing
        token

      when :mass_update, :change_category
        existing = Tag.find_by(name: token[1]).present?
        token[3] = existing
        token

      when :nuke_tag
        errors << "Only admins can nuke tags" unless user.is_admin?
        existing = Tag.find_by(name: token[1]).present?
        token[3] = existing
        token
      else
        errors << "Unknown token: #{token[0]}"
      end
    end
    errors << "Cannot create BUR with more than 25 entries" if tokens.size > 25 && !user.is_admin?
    [errors, BulkUpdateRequestImporter.untokenize(annotated).join("\n")]
  end

  def estimate_update_count
    tokens = self.class.tokenize(text)
    tokens.inject(0) do |sum, token|
      case token[0]
      when :create_alias
        sum + TagAlias.new(antecedent_name: token[1], consequent_name: token[2]).estimate_update_count

      when :create_implication
        sum + TagImplication.new(antecedent_name: token[1], consequent_name: token[2]).estimate_update_count

      when :change_category, :mass_update, :nuke_tag
        sum + (Tag.find_by(name: token[1]).try(:post_count) || 0)

      else
        sum + 0
      end
    end
  end

  private

  ## These functions will find and appropriate existing aliases or implications if needed. This reduces friction with accepting
  # a BUR, and makes it much easier to work with.
  def find_create_alias(token, approver)
    tag_alias = TagAlias.duplicate_relevant.find_by(antecedent_name: token[1], consequent_name: token[2])
    if tag_alias.present?
      return unless tag_alias.status == 'pending'
      tag_alias.update_columns(creator_id: creator_id, creator_ip_addr: creator_ip_addr, forum_topic_id: forum_id)
    else
      tag_alias = TagAlias.create(:forum_topic_id => forum_id, :status => "pending", :antecedent_name => token[1], :consequent_name => token[2])
      unless tag_alias.valid?
        raise Error, "Error: #{tag_alias.errors.full_messages.join("; ")} (create alias #{tag_alias.antecedent_name} -> #{tag_alias.consequent_name})"
      end
    end

    tag_alias.rename_artist
    raise Error, "Error: Alias would modify other aliases or implications through transitive relationships. (create alias #{tag_alias.antecedent_name} -> #{tag_alias.consequent_name})" if tag_alias.has_transitives
    tag_alias.approve!(approver: approver, update_topic: false)
  end

  def find_create_implication(token, approver)
    tag_implication = TagImplication.duplicate_relevant.find_by(antecedent_name: token[1], consequent_name: token[2])
    if tag_implication.present?
      return unless tag_implication.status == 'pending'
      tag_implication.update_columns(creator_id: creator_id, creator_ip_addr: creator_ip_addr, forum_topic_id: forum_id)
    else
      tag_implication = TagImplication.create(:forum_topic_id => forum_id, :status => "pending", :antecedent_name => token[1], :consequent_name => token[2])
      unless tag_implication.valid?
        raise Error, "Error: #{tag_implication.errors.full_messages.join("; ")} (create implication #{tag_implication.antecedent_name} -> #{tag_implication.consequent_name})"
      end
    end

    tag_implication.approve!(approver: approver, update_topic: false)
  end

  def execute(tokens, approver)
    warnings = []
    ActiveRecord::Base.transaction do
      tokens.map do |token|
        case token[0]
        when :create_alias
          find_create_alias(token, approver)

        when :create_implication
          find_create_implication(token, approver)

        when :remove_alias
          tag_alias = TagAlias.active.find_by(antecedent_name: token[1], consequent_name: token[2])
          raise Error, "Alias for #{token[1]} not found" if tag_alias.nil?
          tag_alias.reject!(update_topic: false)

        when :remove_implication
          tag_implication = TagImplication.active.find_by(antecedent_name: token[1], consequent_name: token[2])
          raise Error, "Implication for #{token[1]} not found" if tag_implication.nil?
          tag_implication.reject!(update_topic: false)

        when :mass_update
          TagBatchJob.perform_later(token[1], token[2], CurrentUser.id, CurrentUser.ip_addr)

        when :nuke_tag
          TagNukeJob.perform_later(token[1], CurrentUser.id, CurrentUser.ip_addr)

        when :change_category
          tag = Tag.find_by(name: token[1])
          raise Error, "Tag for #{token[1]} not found" if tag.nil?
          tag.category = Tag.categories.value_for(token[2])
          tag.save

        else
          raise Error, "Unknown token: #{token[0]}"
        end
      end
    end
  end
end
