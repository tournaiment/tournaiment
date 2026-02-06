class BackfillRatedMatchPresetsAndAddConstraint < ActiveRecord::Migration[8.1]
  CONSTRAINT_NAME = "matches_rated_requires_time_control_preset"

  def up
    ensure_fallback_presets!
    backfill_with_matching_category!
    backfill_without_category!
    assert_no_unresolved_rows!

    add_check_constraint :matches,
      "(rated = FALSE) OR (time_control_preset_id IS NOT NULL)",
      name: CONSTRAINT_NAME
  end

  def down
    remove_check_constraint :matches, name: CONSTRAINT_NAME
  end

  private

  def ensure_fallback_presets!
    execute <<~SQL
      INSERT INTO time_control_presets (
        id,
        key,
        game_key,
        category,
        clock_type,
        clock_config,
        rated_allowed,
        active,
        created_at,
        updated_at
      )
      SELECT
        gen_random_uuid(),
        CONCAT('legacy_', unresolved.game_key, '_', unresolved.category, '_rated_backfill_v1'),
        unresolved.game_key,
        unresolved.category,
        'increment',
        '{"base_seconds":600,"increment_seconds":0}'::jsonb,
        TRUE,
        TRUE,
        NOW(),
        NOW()
      FROM (
        SELECT DISTINCT
          game_key,
          CASE
            WHEN time_control IN ('bullet', 'blitz', 'rapid', 'classical') THEN time_control
            ELSE 'rapid'
          END AS category
        FROM matches
        WHERE rated = TRUE
          AND time_control_preset_id IS NULL
      ) AS unresolved
      WHERE NOT EXISTS (
        SELECT 1
        FROM time_control_presets AS tcp
        WHERE tcp.game_key = unresolved.game_key
          AND tcp.category = unresolved.category
          AND tcp.rated_allowed = TRUE
          AND tcp.active = TRUE
      )
      ON CONFLICT (key) DO NOTHING;
    SQL
  end

  def backfill_with_matching_category!
    execute <<~SQL
      UPDATE matches AS m
      SET time_control_preset_id = resolved.time_control_preset_id,
          time_control = COALESCE(m.time_control, resolved.category)
      FROM (
        SELECT m2.id AS match_id, choice.id AS time_control_preset_id, choice.category
        FROM matches AS m2
        JOIN LATERAL (
          SELECT tcp.id, tcp.category
          FROM time_control_presets AS tcp
          WHERE tcp.game_key = m2.game_key
            AND tcp.rated_allowed = TRUE
            AND tcp.active = TRUE
            AND (m2.time_control IS NULL OR tcp.category = m2.time_control)
          ORDER BY tcp.key ASC
          LIMIT 1
        ) AS choice ON TRUE
        WHERE m2.rated = TRUE
          AND m2.time_control_preset_id IS NULL
      ) AS resolved
      WHERE m.id = resolved.match_id;
    SQL
  end

  def backfill_without_category!
    execute <<~SQL
      UPDATE matches AS m
      SET time_control_preset_id = resolved.time_control_preset_id,
          time_control = COALESCE(m.time_control, resolved.category)
      FROM (
        SELECT m2.id AS match_id, choice.id AS time_control_preset_id, choice.category
        FROM matches AS m2
        JOIN LATERAL (
          SELECT tcp.id, tcp.category
          FROM time_control_presets AS tcp
          WHERE tcp.game_key = m2.game_key
            AND tcp.rated_allowed = TRUE
            AND tcp.active = TRUE
          ORDER BY tcp.key ASC
          LIMIT 1
        ) AS choice ON TRUE
        WHERE m2.rated = TRUE
          AND m2.time_control_preset_id IS NULL
      ) AS resolved
      WHERE m.id = resolved.match_id;
    SQL
  end

  def assert_no_unresolved_rows!
    unresolved = select_value(<<~SQL).to_i
      SELECT COUNT(*)
      FROM matches
      WHERE rated = TRUE
        AND time_control_preset_id IS NULL;
    SQL

    return if unresolved.zero?

    raise ActiveRecord::MigrationError,
      "Cannot enforce rated preset constraint: #{unresolved} rated matches remain without time_control_preset_id."
  end
end
