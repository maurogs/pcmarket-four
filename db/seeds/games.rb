games = [
  [ "fortnite", "Fortnite" ],
  [ "league-of-legends", "League of Legends" ],
  [ "valorant", "Valorant" ],
  [ "counter-strike-2", "Counter-Strike 2" ],
  [ "minecraft", "Minecraft" ],
  [ "call-of-duty-warzone", "Call of Duty: Warzone" ],
  [ "cyberpunk-2077", "Cyberpunk 2077" ],
  [ "baldurs-gate-3", "Baldur's Gate 3" ],
  [ "gta-v", "GTA V" ],
  [ "ea-sports-fc", "EA Sports FC" ],
  [ "marvel-rivals", "Marvel Rivals" ],
  [ "monster-hunter-wilds", "Monster Hunter Wilds" ]
].freeze

games.each_with_index do |(slug, name), index|
  game = Game.find_or_initialize_by(slug: slug)
  game.assign_attributes(name: name, position: index + 1, active: true)
  game.save!
end
