# frozen_string_literal: true

module GitHelper
  def self.init
    if Rails.root.join("REVISION").exist?
      @hash = @tag = Rails.root.join("REVISION").read.strip
    elsif system("type git > /dev/null && git rev-parse --show-toplevel > /dev/null")
      @hash = `git rev-parse HEAD`.strip
      @tag = `git describe --abbrev=0`
    else
      @hash = @tag = ""
    end
  end

  def self.tag
    @tag
  end

  def self.hash
    @hash
  end

  def self.version
    @tag || @hash
  end

  def self.short_hash
    @hash[0..8]
  end

  def self.commit_url(commit_hash)
    "#{Danbooru.config.source_code_url}/commit/#{commit_hash}"
  end

  def self.release_url(tag_name)
    "#{Danbooru.config.source_code_url}/releases/tag/#{tag_name}"
  end

  def self.version_url(name)
    return release_url(name) if @hash
    commit_url(name)
  end
end
