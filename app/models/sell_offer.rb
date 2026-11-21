class SellOffer < ApplicationRecord
  CONDITIONS = %w[works_perfectly minor_wear heavy_wear].freeze
  OFFER_VALIDITY = 7.days

  belongs_to :user, inverse_of: :sell_offers
  belongs_to :buyback_price, optional: true, inverse_of: :sell_offers

  enum :item_kind, { gpu: 0, cpu: 1 }
  enum :status, {
    requested: 0,
    offered: 1,
    accepted: 2,
    received: 3,
    paid: 4,
    rejected: 5,
    declined: 6,
    expired: 7
  }

  encrypts :payout_iban

  before_validation :normalise_payout_iban

  validates :item_name, presence: true
  validates :offered_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :payout_iban, iban: true, allow_blank: true
  validates :payout_account_name, presence: true, if: :accepted?
  validates :offer_expires_at, presence: true, if: :offered?

  scope :open, -> { where(status: %i[requested offered accepted received]) }
  scope :expiring, -> { offered.where(offer_expires_at: ..Time.current) }
  scope :recent, -> { order(created_at: :desc) }

  def acceptable?
    offered? && offer_expires_at.present? && offer_expires_at.future?
  end

  def expired?
    status == "expired" || (offered? && offer_expires_at.present? && offer_expires_at.past?)
  end

  def accept!(iban:, account_name:)
    return false unless acceptable?

    update!(
      status: :accepted,
      accepted_at: Time.current,
      payout_iban: iban,
      payout_account_name: account_name.to_s.strip
    )
  end

  def decline!
    return false unless %w[offered accepted].include?(status)

    update!(status: :declined, declined_at: Time.current)
  end

  def mark_received!(notes: nil)
    return false unless accepted?

    update!(status: :received, received_at: Time.current, admin_notes: notes.presence || admin_notes)
  end

  def mark_paid!(notes: nil)
    return false unless received?

    update!(status: :paid, paid_at: Time.current, admin_notes: notes.presence || admin_notes)
  end

  def reject!(notes: nil)
    return false if %w[paid rejected expired].include?(status)

    update!(status: :rejected, rejected_at: Time.current, admin_notes: notes.presence || admin_notes)
  end

  def expire!
    return false unless offered?
    return false unless offer_expires_at.present? && offer_expires_at.past?

    update!(status: :expired)
  end

  def condition_label_key
    CONDITIONS.include?(condition.to_s) ? condition.to_s : "unknown"
  end

  private

  def normalise_payout_iban
    self.payout_iban = payout_iban.to_s.delete(" ").upcase.presence
  end
end
