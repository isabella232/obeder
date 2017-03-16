class User < ApplicationRecord
  validates :name, presence: true
  validates :email, presence: true, restream_email: true

  has_many :user_menus, dependent: :destroy
  has_many :menus, through: :user_menus
end
