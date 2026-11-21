class Region < ApplicationRecord
  belongs_to :country, foreign_key: :country_code, primary_key: :code, inverse_of: :regions
  has_many :users, dependent: :nullify, inverse_of: :region
  has_many :stores, dependent: :nullify, inverse_of: :region
  has_many :listings, dependent: :nullify, inverse_of: :region
  has_many :addresses, dependent: :nullify, inverse_of: :region

  validates :name, presence: true, uniqueness: { scope: :country_code, case_sensitive: false }

  def to_s
    name
  end
end
