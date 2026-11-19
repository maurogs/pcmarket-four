require "test_helper"

class GameTest < ActiveSupport::TestCase
  setup do
    @game = Game.create!(slug: "cyberpunk-2077", name: "Cyberpunk 2077",
      demand: { "1080p" => { "60" => 20, "144" => 45, "240" => 70 }, "1440p" => { "60" => 35 } })
  end

  test "requires slug and name" do
    game = Game.new(name: "")

    assert_not game.valid?
    assert game.errors[:slug].any?
    assert game.errors[:name].any?
  end

  test "slug must be unique" do
    assert_not Game.new(slug: @game.slug, name: "Clone").valid?
  end

  test "defaults" do
    game = Game.create!(slug: "elden-ring", name: "Elden Ring")

    assert_equal 0, game.position
    assert_predicate game, :active
    assert_equal({}, game.demand)
    assert_equal 0.3, game.cpu_weight
  end

  test "required_score reads the demand hash" do
    assert_equal 45, @game.required_score("1080p", "144")
    assert_equal 20, @game.required_score(:"1080p", 60)
    assert_equal 35, @game.required_score("1440p", "60")
  end

  test "required_score is nil for unknown resolution or fps" do
    assert_nil @game.required_score("4k", "60")
    assert_nil @game.required_score("1080p", "30")
  end

  test "active scope filters inactive games and orders by position" do
    second = Game.create!(slug: "elden-ring", name: "Elden Ring", position: 1)
    first = Game.create!(slug: "hades-ii", name: "Hades II", position: -1)
    inactive = Game.create!(slug: "old-game", name: "Old Game", position: 2, active: false)

    assert_equal [ first, @game, second ], Game.active.to_a
    assert_not_includes Game.active, inactive
  end
end
