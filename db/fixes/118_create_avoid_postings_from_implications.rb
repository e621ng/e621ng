#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

CurrentUser.as_system do
  TagImplication.order(created_at: :asc).approved.where(consequent_name: %w[avoid_posting conditional_dnp]).find_each do |implication|
    artist = Artist.find_or_create_by!(name: implication.antecedent_name)
    dnp = CurrentUser.scoped(implication.creator, implication.creator_ip_addr) do
      AvoidPosting.create(artist: artist, created_at: implication.created_at, updated_at: implication.created_at)
    end
    if dnp.valid?
      puts artist.name
    else
      puts "Failed to create dnp for #{artist.name}"
      puts dnp.errors.full_messages
    end
  end
end
