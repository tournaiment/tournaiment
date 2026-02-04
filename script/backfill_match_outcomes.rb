#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../config/environment"

updated = 0

Match.find_each do |match|
  attrs = {}

  if match.termination == "resign" && match.resigned_by_side.blank?
    if match.winner_side == "a"
      attrs[:resigned_by_side] = "b"
    elsif match.winner_side == "b"
      attrs[:resigned_by_side] = "a"
    end
  end

  if %w[illegal_move no_response].include?(match.termination) && match.forfeit_by_side.blank?
    if match.winner_side == "a"
      attrs[:forfeit_by_side] = "b"
    elsif match.winner_side == "b"
      attrs[:forfeit_by_side] = "a"
    end
  end

  if match.result == "1/2-1/2" && match.draw_reason.blank? && match.termination.present?
    attrs[:draw_reason] = match.termination
  end

  next if attrs.empty?

  match.update_columns(attrs.merge(updated_at: Time.current))
  updated += 1
end

puts "Backfill complete. Updated #{updated} matches."
