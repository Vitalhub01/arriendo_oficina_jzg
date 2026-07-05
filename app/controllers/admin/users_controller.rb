# frozen_string_literal: true

module Admin
  class UsersController < Admin::BaseController
    before_action :set_user, only: %i[edit update]

    def index
      @users = User.where(role: %i[owner admin]).order(:name)
    end

    def new
      @user = User.new(role: :owner)
    end

    def edit; end

    def create
      @user = User.new(user_params)
      assign_role(@user)
      temp_password = user_params[:password].presence || SecureRandom.hex(8)
      @user.password = temp_password

      if @user.save
        redirect_to admin_users_path, notice: "Dueño creado. Contraseña: #{temp_password}"
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      @user.assign_attributes(user_params)
      assign_role(@user) if params.dig(:user, :role).present?

      if @user.save
        redirect_to admin_users_path, notice: 'Usuario actualizado'
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_user
      @user = User.find(params.expect(:id))
    end

    def user_params
      params.expect(user: %i[name email password password_confirmation])
    end

    def assign_role(user)
      role = params.dig(:user, :role).to_s
      user.role = %w[owner admin].include?(role) ? role : :owner
    end
  end
end
