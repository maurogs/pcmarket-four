class HelpArticleFeedback < ApplicationRecord
  belongs_to :help_article

  validates :session_id, presence: true, length: { maximum: 64 }
  validates :session_id, uniqueness: { scope: :help_article_id }
  validates :helpful, inclusion: { in: [ true, false ] }

  scope :helpful, -> { where(helpful: true) }
  scope :unhelpful, -> { where(helpful: false) }

  def self.record!(article:, session_id:, helpful:)
    feedback = find_or_initialize_by(help_article: article, session_id: session_id)
    feedback.helpful = ActiveModel::Type::Boolean.new.cast(helpful)
    feedback.save!
    feedback
  end
end
