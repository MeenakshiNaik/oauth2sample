require "#{Rails.root}/app/services/authorize_user_request"

class Api::V1::BaseController < ApplicationController
  before_action :authenticate_request, :access_token_if_expired
  attr_reader :current_user

  private
    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end

    def authenticate_request
      @current_user = AuthorizeUserRequest.call(request.headers).result
      render json: { success: false, error: "Not authorized" }, status: 401 unless @current_user.present?
    end

    def access_token_if_expired
      if current_user.present? && current_user.linked_accounts.present?
        current_user.linked_accounts.each do |linked_account|
          begin
            #checking if access token has been expired after login
            linked_account.access_token_if_expired
          rescue
            next
          end
        end
      end
    end

end