class AuthenticateUser
  require "json_web_token"
  prepend SimpleCommand

  def initialize(email, password)
    @email = email
    @password = password
  end

  def call
    User.get_auth_token(JsonWebToken.encode(user_id: user.id), user) if user
  end

  private

  attr_accessor :email, :password

  def user
    user = User.find_by_email(email)
    return user if user && user.valid_password?(password)

    errors.add :user, I18n.t('errors.user.invalid')
    nil
  end
end