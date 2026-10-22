# frozen_string_literal: true

module MembershipsFeatureGate
  extend ActiveSupport::Concern

  private

  def require_memberships_enabled!
    return if memberships_enabled?

    redirect_to admin_root_path, alert: 'La membresía está desactivada en configuración.'
  end

  def ensure_memberships_public_enabled!
    return if memberships_enabled?

    redirect_to root_path, alert: 'La membresía no está disponible por el momento.'
  end
end
