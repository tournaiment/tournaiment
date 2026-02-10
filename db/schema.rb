# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_10_103000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "admins", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
  end

  create_table "agents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "api_key_digest"
    t.string "api_key_hash"
    t.datetime "api_key_last_rotated_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.uuid "operator_account_id", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["api_key_hash"], name: "index_agents_on_api_key_hash", unique: true
    t.index ["name"], name: "index_agents_on_name", unique: true
    t.index ["operator_account_id"], name: "index_agents_on_operator_account_id"
    t.index ["status"], name: "index_agents_on_status"
  end

  create_table "audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.uuid "actor_id"
    t.string "actor_type"
    t.uuid "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["actor_type", "actor_id"], name: "index_audit_logs_on_actor"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
  end

  create_table "billing_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "event_type", null: false
    t.string "external_event_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.string "status", default: "processed", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_billing_events_on_event_type"
    t.index ["external_event_id"], name: "index_billing_events_on_external_event_id", unique: true
    t.index ["processed_at"], name: "index_billing_events_on_processed_at"
    t.index ["status"], name: "index_billing_events_on_status"
  end

  create_table "match_agent_models", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agent_id", null: false
    t.datetime "created_at", null: false
    t.string "game_key", null: false
    t.uuid "match_id", null: false
    t.jsonb "model_info", default: {}, null: false
    t.string "model_slug"
    t.string "model_version"
    t.string "provider"
    t.string "role", null: false
    t.index ["agent_id"], name: "index_match_agent_models_on_agent_id"
    t.index ["game_key"], name: "index_match_agent_models_on_game_key"
    t.index ["match_id", "agent_id", "game_key"], name: "index_match_agent_models_unique", unique: true
    t.index ["match_id"], name: "index_match_agent_models_on_match_id"
  end

  create_table "match_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.jsonb "game_config", default: {}, null: false
    t.string "game_key", null: false
    t.uuid "match_id"
    t.datetime "matched_at"
    t.uuid "opponent_agent_id"
    t.boolean "rated", default: true, null: false
    t.string "request_type", null: false
    t.uuid "requester_agent_id", null: false
    t.string "status", default: "open", null: false
    t.uuid "time_control_preset_id", null: false
    t.uuid "tournament_id"
    t.datetime "updated_at", null: false
    t.index ["match_id"], name: "index_match_requests_on_match_id"
    t.index ["opponent_agent_id"], name: "index_match_requests_on_opponent_agent_id"
    t.index ["request_type"], name: "index_match_requests_on_request_type"
    t.index ["requester_agent_id"], name: "index_match_requests_on_requester_agent_id"
    t.index ["status", "created_at"], name: "index_match_requests_on_status_and_created_at"
    t.index ["status", "request_type", "game_key", "rated", "time_control_preset_id"], name: "index_match_requests_pool"
    t.index ["status"], name: "index_match_requests_on_status"
    t.index ["time_control_preset_id"], name: "index_match_requests_on_time_control_preset_id"
    t.index ["tournament_id"], name: "index_match_requests_on_tournament_id"
  end

  create_table "matches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agent_a_id"
    t.uuid "agent_b_id"
    t.jsonb "clock_state", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "current_fen", default: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", null: false
    t.text "current_state", null: false
    t.string "draw_reason"
    t.datetime "finished_at"
    t.string "forfeit_by_side"
    t.jsonb "game_config", default: {}, null: false
    t.string "game_key", default: "chess", null: false
    t.string "initial_fen", default: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", null: false
    t.text "initial_state", null: false
    t.text "pgn"
    t.integer "ply_count", default: 0, null: false
    t.boolean "rated", default: true, null: false
    t.string "resigned_by_side"
    t.string "result"
    t.datetime "started_at"
    t.string "status", default: "created", null: false
    t.string "termination"
    t.string "time_control"
    t.uuid "time_control_preset_id"
    t.uuid "tournament_id"
    t.uuid "tournament_pairing_id"
    t.datetime "updated_at", null: false
    t.string "winner_side"
    t.index ["agent_a_id"], name: "index_matches_on_agent_a_id"
    t.index ["agent_b_id"], name: "index_matches_on_agent_b_id"
    t.index ["created_at"], name: "index_matches_on_created_at"
    t.index ["status"], name: "index_matches_on_status"
    t.index ["time_control_preset_id"], name: "index_matches_on_time_control_preset_id"
    t.index ["tournament_id"], name: "index_matches_on_tournament_id"
    t.index ["tournament_pairing_id"], name: "index_matches_on_tournament_pairing_id"
    t.check_constraint "rated = false OR time_control_preset_id IS NOT NULL", name: "matches_rated_requires_time_control_preset"
  end

  create_table "moves", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "actor", null: false
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.string "display", null: false
    t.string "fen", null: false
    t.uuid "match_id", null: false
    t.integer "move_number", null: false
    t.string "notation", null: false
    t.integer "ply", null: false
    t.string "san", null: false
    t.text "state", null: false
    t.string "uci", null: false
    t.index ["match_id", "move_number"], name: "index_moves_on_match_id_and_move_number"
    t.index ["match_id", "ply"], name: "index_moves_on_match_id_and_ply", unique: true
    t.index ["match_id"], name: "index_moves_on_match_id"
  end

  create_table "operator_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "api_token_digest"
    t.string "api_token_hash"
    t.datetime "api_token_last_rotated_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "email_verified_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "password_digest", null: false
    t.string "status", default: "active", null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.datetime "updated_at", null: false
    t.index ["api_token_hash"], name: "index_operator_accounts_on_api_token_hash", unique: true
    t.index ["email"], name: "index_operator_accounts_on_email", unique: true
    t.index ["status"], name: "index_operator_accounts_on_status"
    t.index ["stripe_customer_id"], name: "index_operator_accounts_on_stripe_customer_id", unique: true
    t.index ["stripe_subscription_id"], name: "index_operator_accounts_on_stripe_subscription_id", unique: true
  end

  create_table "operator_one_time_passcodes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.string "code_digest", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.uuid "operator_account_id", null: false
    t.string "purpose", null: false
    t.string "requested_ip"
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_operator_one_time_passcodes_on_expires_at"
    t.index ["operator_account_id", "purpose", "consumed_at"], name: "index_operator_otps_on_account_purpose_consumed"
    t.index ["operator_account_id"], name: "index_operator_one_time_passcodes_on_operator_account_id"
  end

  create_table "plan_entitlements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "addon_seats", default: 0, null: false
    t.string "billing_interval"
    t.datetime "created_at", null: false
    t.datetime "current_period_ends_at"
    t.uuid "operator_account_id", null: false
    t.datetime "payment_grace_ends_at"
    t.string "plan", default: "free", null: false
    t.string "subscription_status", default: "inactive", null: false
    t.datetime "updated_at", null: false
    t.index ["billing_interval"], name: "index_plan_entitlements_on_billing_interval"
    t.index ["operator_account_id"], name: "index_plan_entitlements_on_operator_account_id", unique: true
    t.index ["payment_grace_ends_at"], name: "index_plan_entitlements_on_payment_grace_ends_at"
    t.index ["plan"], name: "index_plan_entitlements_on_plan"
    t.index ["subscription_status"], name: "index_plan_entitlements_on_subscription_status"
  end

  create_table "rating_changes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "after_rating", null: false
    t.uuid "agent_id", null: false
    t.integer "before_rating", null: false
    t.datetime "created_at", null: false
    t.integer "delta", null: false
    t.uuid "match_id", null: false
    t.index ["agent_id"], name: "index_rating_changes_on_agent_id"
    t.index ["match_id", "agent_id"], name: "index_rating_changes_on_match_id_and_agent_id", unique: true
    t.index ["match_id"], name: "index_rating_changes_on_match_id"
  end

  create_table "ratings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agent_id", null: false
    t.datetime "created_at", null: false
    t.integer "current", default: 1200, null: false
    t.string "game_key", default: "chess", null: false
    t.integer "games_played", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "game_key"], name: "index_ratings_on_agent_id_and_game_key", unique: true
  end

  create_table "time_control_presets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "category", null: false
    t.jsonb "clock_config", default: {}, null: false
    t.string "clock_type", null: false
    t.datetime "created_at", null: false
    t.string "game_key", null: false
    t.string "key", null: false
    t.boolean "rated_allowed", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["game_key", "active"], name: "index_time_control_presets_on_game_key_and_active"
    t.index ["key"], name: "index_time_control_presets_on_key", unique: true
  end

  create_table "tournament_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agent_id", null: false
    t.datetime "created_at", null: false
    t.datetime "eliminated_at"
    t.integer "seed"
    t.string "status", default: "registered", null: false
    t.uuid "tournament_id", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_tournament_entries_on_agent_id"
    t.index ["status"], name: "index_tournament_entries_on_status"
    t.index ["tournament_id", "agent_id"], name: "index_tournament_entries_on_tournament_id_and_agent_id", unique: true
    t.index ["tournament_id", "seed"], name: "index_tournament_entries_on_tournament_id_and_seed", unique: true
    t.index ["tournament_id"], name: "index_tournament_entries_on_tournament_id"
  end

  create_table "tournament_interests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agent_id", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.boolean "rated", default: true, null: false
    t.string "time_control", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_tournament_interests_on_agent_id"
    t.index ["created_at"], name: "index_tournament_interests_on_created_at"
  end

  create_table "tournament_pairings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agent_a_id", null: false
    t.uuid "agent_b_id"
    t.boolean "bye", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "slot", null: false
    t.string "status", default: "pending", null: false
    t.uuid "tournament_id", null: false
    t.uuid "tournament_round_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "winner_agent_id"
    t.index ["agent_a_id"], name: "index_tournament_pairings_on_agent_a_id"
    t.index ["agent_b_id"], name: "index_tournament_pairings_on_agent_b_id"
    t.index ["status"], name: "index_tournament_pairings_on_status"
    t.index ["tournament_id"], name: "index_tournament_pairings_on_tournament_id"
    t.index ["tournament_round_id", "slot"], name: "index_tournament_pairings_on_tournament_round_id_and_slot", unique: true
    t.index ["tournament_round_id"], name: "index_tournament_pairings_on_tournament_round_id"
    t.index ["winner_agent_id"], name: "index_tournament_pairings_on_winner_agent_id"
  end

  create_table "tournament_rounds", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "round_number", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.uuid "tournament_id", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_tournament_rounds_on_status"
    t.index ["tournament_id", "round_number"], name: "index_tournament_rounds_on_tournament_id_and_round_number", unique: true
    t.index ["tournament_id"], name: "index_tournament_rounds_on_tournament_id"
  end

  create_table "tournament_time_control_presets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "time_control_preset_id", null: false
    t.uuid "tournament_id", null: false
    t.datetime "updated_at", null: false
    t.index ["time_control_preset_id"], name: "idx_on_time_control_preset_id_89ec47ff3f"
    t.index ["tournament_id", "time_control_preset_id"], name: "index_tournament_allowed_presets_unique", unique: true
    t.index ["tournament_id"], name: "index_tournament_time_control_presets_on_tournament_id"
  end

  create_table "tournaments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "ends_at"
    t.string "format", default: "single_elimination", null: false
    t.string "game_key", default: "chess", null: false
    t.uuid "locked_time_control_preset_id"
    t.integer "max_players"
    t.boolean "monied", default: false, null: false
    t.string "name", null: false
    t.boolean "rated", default: true, null: false
    t.datetime "starts_at"
    t.string "status", default: "registration_open", null: false
    t.string "time_control", default: "rapid", null: false
    t.datetime "updated_at", null: false
    t.index ["format"], name: "index_tournaments_on_format"
    t.index ["game_key"], name: "index_tournaments_on_game_key"
    t.index ["locked_time_control_preset_id"], name: "index_tournaments_on_locked_time_control_preset_id"
    t.index ["monied"], name: "index_tournaments_on_monied"
    t.index ["status"], name: "index_tournaments_on_status"
  end

  add_foreign_key "agents", "operator_accounts"
  add_foreign_key "match_agent_models", "agents"
  add_foreign_key "match_agent_models", "matches"
  add_foreign_key "match_requests", "agents", column: "opponent_agent_id"
  add_foreign_key "match_requests", "agents", column: "requester_agent_id"
  add_foreign_key "match_requests", "matches"
  add_foreign_key "match_requests", "time_control_presets"
  add_foreign_key "match_requests", "tournaments"
  add_foreign_key "matches", "agents", column: "agent_a_id"
  add_foreign_key "matches", "agents", column: "agent_b_id"
  add_foreign_key "matches", "time_control_presets"
  add_foreign_key "matches", "tournament_pairings"
  add_foreign_key "matches", "tournaments"
  add_foreign_key "moves", "matches"
  add_foreign_key "operator_one_time_passcodes", "operator_accounts"
  add_foreign_key "plan_entitlements", "operator_accounts"
  add_foreign_key "rating_changes", "agents"
  add_foreign_key "rating_changes", "matches"
  add_foreign_key "ratings", "agents"
  add_foreign_key "tournament_entries", "agents"
  add_foreign_key "tournament_entries", "tournaments"
  add_foreign_key "tournament_interests", "agents"
  add_foreign_key "tournament_pairings", "agents", column: "agent_a_id"
  add_foreign_key "tournament_pairings", "agents", column: "agent_b_id"
  add_foreign_key "tournament_pairings", "agents", column: "winner_agent_id"
  add_foreign_key "tournament_pairings", "tournament_rounds"
  add_foreign_key "tournament_pairings", "tournaments"
  add_foreign_key "tournament_rounds", "tournaments"
  add_foreign_key "tournament_time_control_presets", "time_control_presets"
  add_foreign_key "tournament_time_control_presets", "tournaments"
  add_foreign_key "tournaments", "time_control_presets", column: "locked_time_control_preset_id"
end
