require "#{Rails.root}/app/services/authorize_user_request"

class Api::V1::UsersController < Api::V1::BaseController

  # this method is used to get refresh token from serverAuthCode provided by android device.
  def validate_server_auth_code
    if current_user.present?
      serverAuthCode = params[:serverAuthCode]
      response = current_user.get_refresh_token_for_device(serverAuthCode)
      if response["refresh_token"].present?
        auth = {
          provider: "google_oauth2",
          uid: params["userId"],
          info: {
            email: params["user"]["email"],
            name: params["displayName"],
            image: params["imageUrl"]
          },
          credentials: {
            token: params["accessToken"],
            expires: params["expires"],
            expires_in: DateTime.now().to_i + response["expires_in"],
            refresh_token: response["refresh_token"]
          }
        }
        linked_account = current_user.linked_accounts.where(email: params["user"]["email"]).last
        same_email_addresses = LinkedAccount.where(email: params["user"]["email"])
        if same_email_addresses.present?
          same_email_addresses.each do |same_email_address|
            same_email_address.update_auth_token(auth)
          end
        end
        if linked_account.present?
          render json: { success: true, msg: "You have already linked this account!" }, status: 200
        else
          new_linked_account = LinkedAccount.add_details(current_user, auth, "mobile")
          if new_linked_account.present?
            date = new_linked_account.emails.last.received_at.to_date if new_linked_account.emails.present?
            User.fetch_emails_from_gmail(new_linked_account, date)
            render json: { success: true, msg: "Account linked successfully!" }, status: 200
          else
            render json: { success: false, msg: "Something went wrong!" }, status: 422
          end
        end
      else
        Rails.logger.info { "#{'*-'*20} #{response['error_description']} #{'*-'*20}" }
        render json: { success: false, msg: response["error_description"] }, status: 422
      end
    else
      render json: { success: false, error: "Not authorized" }, status: 401
    end
  end

end
