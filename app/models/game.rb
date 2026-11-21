class Game < ApplicationRecord
  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }
  scope :visible, -> { active.ordered }

  def to_param
    slug
  end
end
