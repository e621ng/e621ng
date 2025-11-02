# script/sitemap_roles.rb
# Usage: bin/rails runner script/sitemap_roles.rb > tmp/routes_with_roles.csv

require_relative "config/environment"
require "csv"

Rails.application.eager_load!

ROLE_GUARD_SUFFIX = "_only"
ROLE_DESCRIPTIONS = {
  "public" => "Public",
  "logged_in_only" => "Logged-in user",
  "member_only" => "Member+",
  "privileged_only" => "Privileged+",
  "former_staff_only" => "Former Staff",
  "janitor_only" => "Janitor+",
  "moderator_only" => "Moderator+",
  "admin_only" => "Admin only",
  "approver_only" => "Approver (can_approve_posts flag)",
  "is_bd_staff_only" => "BD staff flag",
  "can_view_staff_notes_only" => "Can view staff notes flag",
  "can_handle_takedowns_only" => "Takedown team flag",
  "can_edit_avoid_posting_entries_only" => "Avoid posting editor flag",
}.freeze

ROLE_RANK = {
  "public" => -1,
  "logged_in_only" => User::Levels::MEMBER - 1,
  "member_only" => User::Levels::MEMBER,
  "approver_only" => User::Levels::MEMBER,
  "privileged_only" => User::Levels::PRIVILEGED,
  "former_staff_only" => User::Levels::FORMER_STAFF,
  "janitor_only" => User::Levels::JANITOR,
  "is_bd_staff_only" => User::Levels::JANITOR, # bit flag layered on top of janitor+
  "can_edit_avoid_posting_entries_only" => User::Levels::JANITOR,
  "moderator_only" => User::Levels::MODERATOR,
  "can_view_staff_notes_only" => User::Levels::MODERATOR,
  "can_handle_takedowns_only" => User::Levels::MODERATOR,
  "admin_only" => User::Levels::ADMIN
}.freeze
UNKNOWN_GUARD_RANK = ROLE_RANK.values.max + 10

def guard_rank(name)
  ROLE_RANK.fetch(name, UNKNOWN_GUARD_RANK)
end

def guard_label(name)
  ROLE_DESCRIPTIONS[name] || name.sub(/_only\z/, "").humanize
end

def guard_applies_to_action?(callback, action)
  action = action.to_s
  only_filters = Array(callback.instance_variable_get(:@if)).select do |filter|
    filter.is_a?(AbstractController::Callbacks::ActionFilter) &&
      filter.instance_variable_get(:@filters).include?(callback.filter) &&
      filter.instance_variable_get(:@conditional_key) == :only
  end
  except_filters = Array(callback.instance_variable_get(:@unless)).select do |filter|
    filter.is_a?(AbstractController::Callbacks::ActionFilter) &&
      filter.instance_variable_get(:@filters).include?(callback.filter) &&
      filter.instance_variable_get(:@conditional_key) == :except
  end

  if only_filters.any?
    only_filters.any? { |f| f.instance_variable_get(:@actions).include?(action) }
  elsif except_filters.any?
    except_filters.none? { |f| f.instance_variable_get(:@actions).include?(action) }
  else
    true
  end
end

def guard_callbacks(controller, action)
  controller._process_action_callbacks.select do |callback|
    callback.kind == :before &&
      callback.filter.is_a?(Symbol) &&
      callback.filter.to_s.end_with?(ROLE_GUARD_SUFFIX) &&
      guard_applies_to_action?(callback, action)
  end.map { |callback| callback.filter.to_s }
end

puts CSV.generate_line(%w[verb path action guards min_role])

Rails.application.routes.routes.each do |route|
  next if route.internal

  controller_path = route.defaults[:controller]
  action = route.defaults[:action]
  next unless controller_path && action

  controller = "#{controller_path.camelize}Controller".safe_constantize
  next unless controller && controller <= ApplicationController

  verb_pattern = route.verb
  verbs = case verb_pattern
          when nil
            %w[GET POST PUT PATCH DELETE OPTIONS HEAD]
          when Regexp
            verb_pattern.source.delete_prefix("^").delete_suffix("$").split("|")
          else
            verb_pattern.split("|")
          end
  next unless verbs.any? { |verb| %w[GET HEAD].include?(verb) }

  guards = guard_callbacks(controller, action)
  guards = ["public"] if guards.empty?
  guard_labels = guards.map { |name| guard_label(name) }.uniq
  min_role = guard_label(guards.max_by { |name| guard_rank(name) })

  row = [
    verbs.join("|"),
    route.path.spec.to_s,
    "#{controller.name}##{action}",
    guard_labels.join("|"),
    min_role
  ]
  puts CSV.generate_line(row)
end
