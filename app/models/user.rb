# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  name                   :string
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :inet
#  last_sign_in_ip        :inet
#  confirmation_token     :string
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#

require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'signet/oauth_2/client'
require 'fileutils'
require 'net/http'
require 'uri'
require 'json'
require 'action_view'

class User < ApplicationRecord

  include ActionView::Helpers::NumberHelper

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  has_many :linked_accounts, dependent: :destroy

  validates :email, presence: true, format: Devise.email_regexp
  validates :password, length: { minimum: 8 }, if: Proc.new { |user| user.password.present? }

  APPLICATION_NAME = Rails.application.secrets.application_name
  SCOPE = 'userinfo.email, https://www.googleapis.com/auth/gmail.readonly, userinfo.profile'

  # this method is for web oauth athentication not for mobile side
  def self.from_omniauth(auth, user)
    data = auth[:info]
    linked_account = LinkedAccount.add_details(user, auth, "web") if user.present?
    date = linked_account.emails.last.received_at.to_date if linked_account.emails.present?
    User.fetch_emails_from_gmail(linked_account, date) if linked_account.present?
    user
  end

  # this is the main gmail authentication of linked account
  def self.authentication(linked_account)
    auth = Signet::OAuth2::Client.new(
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      token_credential_uri: Rails.application.secrets.token_credential_uri,
      client_id: Rails.application.secrets.google_client_id,
      client_secret: Rails.application.secrets.google_client_secret,
      scope: User::SCOPE,
      redirect_uri: Rails.application.secrets.redirect_uri,
      refresh_token: linked_account[:refresh_token]
    )
    # if linked_account.token_updated_at <= 58.minutes.ago
    if auth.fetch_access_token!
      linked_account.update!(token: auth.access_token, refresh_token: auth.refresh_token, expires_at: auth.expires_at
      auth
    else
      return false
    end
  end

  # to fetch refresh token from serverAuthCode
  def get_refresh_token_for_device(serverAuthCode)
    data = {
            client_id: Rails.application.secrets.google_client_id,
            client_secret: Rails.application.secrets.google_client_secret,
            grant_type: "authorization_code",
            code: serverAuthCode,
            redirect_uri: Rails.application.secrets.redirect_uri
          }
    request = Net::HTTP.post_form(URI.parse('https://accounts.google.com/o/oauth2/token'), data)
    response = JSON(request.body)
    return response
  end


  def self.fetch_emails_from_gmail(linked_account, date=nil)
    gmail = User.get_gmail_service(linked_account)
    if gmail
      after = date.present? ? date : linked_account.created_at.to_date - 3
      query = "after: #{after}"
      email_list = gmail.list_user_messages(linked_account[:uid], q: "#{query}")

      email_array = parse_messages(email_list, gmail)
      emails = Email.add(email_array, linked_account)
      emails
    else
      return false
    end
  end

  def self.get_gmail_service(linked_account)
    # if (linked_account.expires || Time.now.to_i - 10) > Time.now.to_i
    #   Rails.logger.info { "\n\n token expirred" }
    auth = User.authentication(linked_account)
    # else
    #   Rails.logger.info { "\n\n token not expirred" }
    #### I tried to use this AccessToken to but its not working either
    #### AccessToken is working for web oauth though
    #   auth = AccessToken.new(linked_account.token)
    #   Rails.logger.info { "\n\n get_gmail_service auth -- #{auth}" }
    # end
    if auth
      gmail = Google::Apis::GmailV1::GmailService.new
      gmail.client_options.application_name = APPLICATION_NAME
      gmail.authorization = auth
      gmail
    else
      return false
    end
  end

  # to fetch emails in every 10 minutes interval - for cron job
  def self.refresh_all_linked_accounts
    if User.count > 0
      User.all.each do |user|
        if user.linked_accounts.present?
          last_email = user.emails.order('created_at desc').first
          user.linked_accounts.each do |linked_account|
            date = linked_account.emails.last.received_at.to_date if linked_account.emails.present?
            begin
              User.fetch_emails_from_gmail(linked_account, date)
            rescue Exception => e
              next
            end
          end
        end
      end
    end
  end

end

class AccessToken
  attr_reader :token
  def initialize(token)
    @token = token
  end

  def apply!(headers)
    headers['Authorization'] = "Bearer #{@token}"
  end
end