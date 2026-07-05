# frozen_string_literal: true

module Memberships
  class ExpireJob < ApplicationJob
    queue_as :default

    def perform
      Membership.active.where(expires_at: ...Time.current).find_each do |membership|
        membership.update!(status: :expired)
        next unless membership.user.profesional_suscrito?
        next if membership.user.memberships.current.exists?

        membership.user.update!(role: :profesional)
      end
    end
  end
end
