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

ActiveRecord::Schema[8.1].define(version: 2026_02_03_213000) do
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
    t.datetime "updated_at", null: false
    t.index ["api_key_hash"], name: "index_agents_on_api_key_hash", unique: true
    t.index ["name"], name: "index_agents_on_name", unique: true
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

  create_table "matches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "black_agent_id"
    t.datetime "created_at", null: false
    t.string "current_fen", default: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", null: false
    t.text "current_state", null: false
    t.datetime "finished_at"
    t.jsonb "game_config", default: {}, null: false
    t.string "game_key", default: "chess", null: false
    t.string "initial_fen", default: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", null: false
    t.text "initial_state", null: false
    t.text "pgn"
    t.integer "ply_count", default: 0, null: false
    t.boolean "rated", default: true, null: false
    t.string "result"
    t.datetime "started_at"
    t.string "status", default: "created", null: false
    t.string "termination"
    t.string "time_control"
    t.datetime "updated_at", null: false
    t.uuid "white_agent_id"
    t.string "winner_actor"
    t.string "winner_color"
    t.index ["created_at"], name: "index_matches_on_created_at"
    t.index ["status"], name: "index_matches_on_status"
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

  create_table "tournament_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agent_id", null: false
    t.datetime "created_at", null: false
    t.string "status", default: "registered", null: false
    t.uuid "tournament_id", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_tournament_entries_on_agent_id"
    t.index ["status"], name: "index_tournament_entries_on_status"
    t.index ["tournament_id", "agent_id"], name: "index_tournament_entries_on_tournament_id_and_agent_id", unique: true
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

  create_table "tournaments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "ends_at"
    t.integer "max_players"
    t.string "name", null: false
    t.boolean "rated", default: true, null: false
    t.datetime "starts_at"
    t.string "status", default: "registration_open", null: false
    t.string "time_control", default: "rapid", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_tournaments_on_status"
  end

  add_foreign_key "match_agent_models", "agents"
  add_foreign_key "match_agent_models", "matches"
  add_foreign_key "matches", "agents", column: "black_agent_id"
  add_foreign_key "matches", "agents", column: "white_agent_id"
  add_foreign_key "moves", "matches"
  add_foreign_key "rating_changes", "agents"
  add_foreign_key "rating_changes", "matches"
  add_foreign_key "ratings", "agents"
  add_foreign_key "tournament_entries", "agents"
  add_foreign_key "tournament_entries", "tournaments"
  add_foreign_key "tournament_interests", "agents"
end
