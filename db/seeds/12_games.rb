# PC Finder game catalog: per-resolution/fps benchmark targets on the same
# 0–100 scale as the GPU performance scores (a target above 100 means no
# current GPU reaches it). Helpers live in earlier seed files.

# rubocop:disable Layout/LineLength
GAMES = [
  # Light esports titles: any modern mid-range GPU hits high frame rates.
  [ "league-of-legends", "League of Legends", { "1080p" => { "60" => 5, "144" => 10, "240" => 18 }, "1440p" => { "60" => 8, "144" => 16, "240" => 30 }, "2160p" => { "60" => 15, "144" => 28, "240" => 55 } } ],
  [ "valorant", "Valorant", { "1080p" => { "60" => 5, "144" => 10, "240" => 16 }, "1440p" => { "60" => 8, "144" => 15, "240" => 28 }, "2160p" => { "60" => 14, "144" => 26, "240" => 50 } } ],
  [ "minecraft", "Minecraft", { "1080p" => { "60" => 8, "144" => 15, "240" => 28 }, "1440p" => { "60" => 12, "144" => 24, "240" => 45 }, "2160p" => { "60" => 25, "144" => 45, "240" => 80 } } ],
  [ "fortnite", "Fortnite", { "1080p" => { "60" => 12, "144" => 25, "240" => 45 }, "1440p" => { "60" => 22, "144" => 40, "240" => 70 }, "2160p" => { "60" => 40, "144" => 68, "240" => 110 } } ],
  [ "marvel-rivals", "Marvel Rivals", { "1080p" => { "60" => 15, "144" => 30, "240" => 50 }, "1440p" => { "60" => 26, "144" => 48, "240" => 78 }, "2160p" => { "60" => 45, "144" => 75, "240" => 115 } } ],
  # AAA titles: 1440p/144 needs an upper mid-range card, 4K/240 is out of reach.
  [ "gta-v", "GTA V", { "1080p" => { "60" => 20, "144" => 38, "240" => 60 }, "1440p" => { "60" => 32, "144" => 55, "240" => 85 }, "2160p" => { "60" => 50, "144" => 80, "240" => 115 } } ],
  [ "baldurs-gate-3", "Baldur's Gate 3", { "1080p" => { "60" => 30, "144" => 55, "240" => 80 }, "1440p" => { "60" => 45, "144" => 70, "240" => 100 }, "2160p" => { "60" => 65, "144" => 92, "240" => 125 } } ],
  [ "warzone", "Warzone", { "1080p" => { "60" => 35, "144" => 58, "240" => 85 }, "1440p" => { "60" => 50, "144" => 75, "240" => 105 }, "2160p" => { "60" => 70, "144" => 98, "240" => 130 } } ],
  [ "cyberpunk-2077", "Cyberpunk 2077", { "1080p" => { "60" => 45, "144" => 70, "240" => 95 }, "1440p" => { "60" => 60, "144" => 85, "240" => 115 }, "2160p" => { "60" => 80, "144" => 105, "240" => 140 } } ],
  [ "monster-hunter-wilds", "Monster Hunter Wilds", { "1080p" => { "60" => 50, "144" => 75, "240" => 100 }, "1440p" => { "60" => 68, "144" => 92, "240" => 125 }, "2160p" => { "60" => 88, "144" => 115, "240" => 150 } } ]
].freeze
# rubocop:enable Layout/LineLength

GAMES.each_with_index do |(slug, name, demand), index|
  seed_record(Game, {
    slug: slug,
    name: name,
    position: index + 1,
    active: true,
    demand: demand
  }, %i[slug])
end
