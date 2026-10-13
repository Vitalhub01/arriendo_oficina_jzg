# frozen_string_literal: true

module Admin
  class UsersController < Admin::BaseController
    before_action :set_user, only: %i[edit update]
    before_action :guard_self_admin_change, only: :update

    def index
      scope = User.order(:name)
      scope = scope.where(role: params[:role]) if User.roles.key?(params[:role].to_s)
      if params[:q].present?
        term = "%#{User.sanitize_sql_like(params[:q].strip)}%"
        scope = scope.where('name ILIKE ? OR email ILIKE ?', term, term)
      end
      @pagy, @users = pagy(scope)
    end

    def edit; end

    def update
      @user.assign_attributes(user_params)
      apply_role! if params.dig(:user, :role).present?
      apply_ban_flag!

      if @user.save
        redirect_to admin_users_path, notice: 'Permisos actualizados'
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_user
      @user = User.find(params.expect(:id))
    end

    def user_params
      params.expect(user: %i[name email])
    end

    def apply_role!
      role = params.dig(:user, :role).to_s
      return unless User.roles.key?(role)

      @user.role = role
    end

    def apply_ban_flag!
      return unless params[:user].key?(:banned)

      if ActiveModel::Type::Boolean.new.cast(params[:user][:banned])
        @user.banned_at ||= Time.current
      else
        @user.banned_at = nil
      end
    end

    def guard_self_admin_change
      return unless @user.id == current_user.id

      new_role = params.dig(:user, :role).to_s
      if new_role.present? && new_role != 'admin'
        redirect_to edit_admin_user_path(@user), alert: 'No puedes quitarte el rol de administrador'
        return
      end

      return unless ActiveModel::Type::Boolean.new.cast(params.dig(:user, :banned))

      redirect_to edit_admin_user_path(@user), alert: 'No puedes bloquear tu propia cuenta'
    end
  end
end
