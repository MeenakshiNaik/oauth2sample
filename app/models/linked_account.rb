# == Schema Information
#
# Table name: linked_accounts
#
#  id               :integer          not null, primary key
#  user_id          :integer
#  email            :string
#  provider         :string
#  uid              :string
#  token            :string
#  expires          :integer
#  expires_at       :integer
#  refresh_token    :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  display_name     :string           default(""), not null
#  profile_image    :string           default(""), not null
#  token_updated_at :datetime
#

# require 'rest-client'

class LinkedAccount < ApplicationRecord

  belongs_to :user

  validates_presence_of :refresh_token

  after_destroy :delete_unimportant_domains_emails

  def self.add_details(user, auth, from)
    Rails.logger.info { "#{'0'*20} linked_account add - #{auth}  #{'0'*20}" }
    where(provider: auth[:provider], uid: auth[:uid], user_id: user.id).first_or_initialize.tap do |linked_account|
      linked_account.user_id = user.id
      linked_account.provider = auth[:provider]
      linked_account.uid = auth[:uid]
      linked_account.token = auth[:credentials][:token]
      linked_account.expires = auth[:credentials][:expires]
      linked_account.expires_at = auth[:credentials][:expires_in]
      linked_account.refresh_token = auth[:credentials][:refresh_token]
      linked_account.email = auth[:info][:email]
      linked_account.display_name = auth[:info][:name]
      linked_account.profile_image = auth[:info][:image]
      linked_account.token_updated_at = DateTime.now
    end
  end

  def update_auth_token(auth)
    self.token_updated_at = Time.now
    self.token = auth[:credentials][:token]
    self.expires = auth[:credentials][:expires]
    self.expires_at = auth[:credentials][:expires]
    self.refresh_token = auth[:credentials][:refresh_token] if auth[:credentials][:refresh_token].present?
    self.save!
  end

  # checking if acces token expired
  def access_token_if_expired
    if self.token_updated_at <= 58.minutes.ago
      data = {
              client_id: Rails.application.secrets.google_client_id,
              client_secret: Rails.application.secrets.google_client_secret,
              grant_type: "refresh_token",
              refresh_token: self.refresh_token
            }
      begin
        response = Net::HTTP.post_form(URI.parse('https://accounts.google.com/o/oauth2/token'), data)
        refreshhash = JSON.parse(response.body)
        unless refreshhash["error"].present?
          self.token_updated_at = DateTime.now
          self.token     = refreshhash['access_token']
          self.expires_at = DateTime.now.to_i +  refreshhash["expires_in"]
          self.save
          User.authentication(self)
        end
      rescue Exception => e
      end
    else
      Rails.logger.info {  "#{'2'*20} refresh token not expired #{'2'*20}" }
    end
  end

end
