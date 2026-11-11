# frozen_string_literal: true

class PasswordResetRequest < ApplicationRecord
  GROUPING_WINDOW = 24.hours

  belongs_to :user, optional: true
  belongs_to :resolved_by, class_name: 'User', optional: true

  enum :status, { pending: 0, resolved: 1 }

  validates :email, presence: true

  scope :newest_first, -> { order(created_at: :desc) }
  scope :pending_first, -> { order(Arel.sql('CASE WHEN status = 0 THEN 0 ELSE 1 END'), created_at: :desc) }

  Group = Struct.new(:requests, keyword_init: true) do
    def representative
      requests.max_by(&:created_at)
    end

    def count
      requests.size
    end

    def pending?
      requests.any?(&:pending?)
    end

    def first_at
      requests.min_by(&:created_at).created_at
    end

    def last_at
      representative.created_at
    end
  end

  def self.grouped_day_windows(requests)
    requests
      .group_by(&:email)
      .flat_map { |_email, email_requests| clusters_for_email(email_requests) }
      .sort_by { |group| group.last_at }
      .reverse
  end

  def self.clusters_for_email(requests)
    sorted = requests.sort_by(&:created_at)
    clusters = []
    current = []

    sorted.each do |req|
      if current.empty? || req.created_at - current.last.created_at <= GROUPING_WINDOW
        current << req
      else
        clusters << Group.new(requests: current)
        current = [req]
      end
    end

    clusters << Group.new(requests: current) if current.any?
    clusters
  end

  def self.cluster_containing(record)
    clusters_for_email(where(email: record.email).to_a)
      .find { |cluster| cluster.requests.any? { |r| r.id == record.id } }
      &.requests || [record]
  end

  def self.pending_group_count
    grouped_day_windows(pending.to_a).count(&:pending?)
  end

  def cluster_members
    @cluster_members ||= self.class.cluster_containing(self)
  end

  def resolve!(by:)
    PasswordResetRequest.transaction do
      cluster_members.each do |req|
        next unless req.pending?

        req.update!(status: :resolved, resolved_at: Time.current, resolved_by: by)
      end
    end
    reload
  end
end
