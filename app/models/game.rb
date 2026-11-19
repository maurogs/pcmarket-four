# PC Finder catalog entry: a game with per-resolution/fps benchmark targets
# (`demand`) used to match listings by their performance_score.
class Game < ApplicationRecord
  has_one_attached :image

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active, -> { where(active: true).order(:position, :id) }

  # Required performance score for a resolution/fps pair, e.g.
  # required_score("1080p", "144") => 45; nil when the game has no such target.
  def required_score(resolution, fps)
    demand.dig(resolution.to_s, fps.to_s)&.to_i
  end
end
