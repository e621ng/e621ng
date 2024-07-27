#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

ModAction.where(action: "user_feedback_delete").update_all("action = 'user_feedback_destroy'")
