require "#{Rails.root}/app/services/authorize_user_request"

class Api::V1::DomainsController < Api::V1::BaseController

  def refresh_inbox
    # This method is to refresh inbox emails
    linked_accounts = current_user.linked_accounts
    if linked_accounts.present?
      linked_accounts.each do |linked_account|
        date = linked_account.emails.last.received_at.to_date if linked_account.emails.present?
        begin
          User.fetch_emails_from_gmail(linked_account, date)
        rescue Exception => e
          Rails.logger.info { "\n\n linked_account -- #{linked_account.inspect}" }
          next
        end
      end
      render json: { success: true }, status: 200
    else
      render json: { success: false, msg: "No accounts added!" }, status: 200
    end
  end

end
