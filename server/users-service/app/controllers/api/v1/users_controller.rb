# frozen_string_literal: true

module Api
  module V1
    class UsersController < ApplicationController
      before_action :set_user, only: [:show, :update, :destroy]

      # GET /api/v1/users
      def index
        @users = User.active.page(params[:page]).per(params[:per_page] || 25)

        render json: {
          users: @users.as_json(except: [:password_digest]),
          meta: pagination_meta(@users)
        }
      end

      # GET /api/v1/users/:id
      def show
        render json: {
          user: @user.as_json(
            except: [:password_digest],
            include: {
              medical_records: { only: [:id, :record_type, :title, :recorded_at] },
              allergies: { only: [:id, :allergen, :severity, :active] }
            }
          )
        }
      end

      # POST /api/v1/users
      def create
        @user = AuthenticationService.register(user_params)

        render json: {
          user: @user.as_json(except: [:password_digest])
        }, status: :created
      rescue AuthenticationService::ValidationError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # PATCH/PUT /api/v1/users/:id
      def update
        if @user.update(user_update_params)
          render json: {
            user: @user.as_json(except: [:password_digest])
          }
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/users/:id
      def destroy
        @user.update(active: false)
        head :no_content
      end

      # GET /api/v1/users/search
      def search
        @users = User.active

        @users = @users.by_email(params[:email]) if params[:email].present?
        @users = @users.search_by_name(params[:name]) if params[:name].present?
        @users = @users.search_by_phone(params[:phone]) if params[:phone].present?

        @users = @users.page(params[:page]).per(params[:per_page] || 25)

        render json: {
          users: @users.as_json(except: [:password_digest]),
          meta: pagination_meta(@users)
        }
      end

      private

      def set_user
        @user = User.active.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "User not found" }, status: :not_found
      end

      def user_params
        params.require(:user).permit(
          :email,
          :password,
          :password_confirmation,
          :first_name,
          :last_name,
          :date_of_birth,
          :gender,
          :phone_number,
          :address,
          :city,
          :state,
          :zip_code,
          :profile_picture_url,
          :emergency_contact_name,
          :emergency_contact_phone
        )
      end

      def user_update_params
        params.require(:user).permit(
          :first_name,
          :last_name,
          :date_of_birth,
          :gender,
          :phone_number,
          :address,
          :city,
          :state,
          :zip_code,
          :profile_picture_url,
          :emergency_contact_name,
          :emergency_contact_phone
        )
      end

      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          next_page: collection.next_page,
          prev_page: collection.prev_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count
        }
      end
    end
  end
end
