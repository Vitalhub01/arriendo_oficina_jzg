# frozen_string_literal: true

class PasswordResetRequest < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :resolved_by, class_name: 'User', optional: true

  enum :status, { pending: 0, resolved: 1 }

  validates :email, presence: true

  scope :newest_first, -> { order(created_at: :desc) }
  scope :pending_first, -> { order(Arel.sql('CASE WHEN status = 0 THEN 0 ELSE 1 END'), created_at: :desc) }

  def resolve!(by:)
    update!(status: :resolved, resolved_at: Time.current, resolved_by: by)
  end
end
