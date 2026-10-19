# frozen_string_literal: true

module Admin
  class SocialContactsController < Admin::BaseController
    before_action :set_social_contact, only: %i[edit update destroy]

    def index
      @social_contacts = SocialContact.ordered
    end

    def new
      @social_contact = SocialContact.new
    end

    def edit; end

    def create
      @social_contact = SocialContact.new(social_contact_params)

      if @social_contact.save
        redirect_to admin_social_contacts_path, notice: 'Contacto de red social creado'
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @social_contact.update(social_contact_params)
        redirect_to admin_social_contacts_path, notice: 'Contacto de red social actualizado'
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @social_contact.destroy
      redirect_to admin_social_contacts_path, notice: 'Contacto de red social eliminado'
    end

    private

    def set_social_contact
      @social_contact = SocialContact.find(params.expect(:id))
    end

    def social_contact_params
      params.expect(social_contact: %i[name username url position visible icon])
    end
  end
end
