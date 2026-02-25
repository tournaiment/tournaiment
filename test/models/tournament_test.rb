require "test_helper"

class TournamentTest < ActiveSupport::TestCase
  test "to_param uses short id with readable slug" do
    tournament = Tournament.create!(
      name: "Spring Championship Invitational 2026",
      status: "registration_open",
      time_control: "rapid",
      rated: true,
      format: "single_elimination",
      game_key: "chess"
    )

    assert_match(/\A[0-9A-Za-z-]+\z/, tournament.to_param)
    assert tournament.to_param.end_with?(tournament.short_id)
    assert_operator tournament.short_id.length, :<, tournament.id.length
    assert_operator tournament.short_id.length, :<=, 22
  end

  test "id_from_param resolves short slug params and legacy uuid params" do
    tournament = Tournament.create!(
      name: "Resolver Cup",
      status: "registration_open",
      time_control: "rapid",
      rated: true,
      format: "single_elimination",
      game_key: "chess"
    )

    assert_equal tournament.id, Tournament.id_from_param(tournament.to_param)
    assert_equal tournament.id, Tournament.id_from_param(tournament.id)
    legacy_short_id = tournament.id.delete("-").to_i(16).to_s(36)
    assert_equal tournament.id, Tournament.id_from_param("resolver-cup-#{legacy_short_id}")
    assert_nil Tournament.id_from_param("invalid-slug-value")
  end

  test "defaults tournament time zone to utc" do
    tournament = Tournament.create!(
      name: "TZ Default Cup",
      status: "registration_open",
      time_control: "rapid",
      rated: true,
      format: "single_elimination",
      game_key: "chess"
    )

    assert_equal Tournament::DEFAULT_TIME_ZONE, tournament.time_zone
  end

  test "requires an iana time zone identifier" do
    tournament = Tournament.new(
      name: "Invalid TZ Cup",
      status: "registration_open",
      time_control: "rapid",
      rated: true,
      format: "single_elimination",
      game_key: "chess",
      time_zone: "GMT+8"
    )

    assert_not tournament.valid?
    assert_includes tournament.errors[:time_zone], "must be a valid IANA timezone identifier"
  end

  test "allows time zone updates before tournament starts" do
    tournament = Tournament.create!(
      name: "Editable TZ Cup",
      status: "registration_open",
      time_control: "rapid",
      rated: true,
      format: "single_elimination",
      game_key: "chess",
      time_zone: "UTC"
    )

    assert tournament.update(time_zone: "Asia/Singapore")
    assert_equal "Asia/Singapore", tournament.reload.time_zone
  end

  test "locks time zone updates once tournament is running" do
    tournament = Tournament.create!(
      name: "Locked TZ Cup",
      status: "running",
      time_control: "rapid",
      rated: true,
      format: "single_elimination",
      game_key: "chess",
      time_zone: "UTC"
    )

    assert_not tournament.update(time_zone: "Asia/Singapore")
    assert_includes tournament.errors[:time_zone], "cannot be changed after tournament starts"
  end
end
