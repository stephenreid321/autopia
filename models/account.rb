class Account
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :email, type: String
  field :admin, type: Boolean
  field :time_zone, type: String
  field :crypted_password, type: String
  field :address_hash, type: String
  field :link, type: String
  field :slack_member, type: Boolean

  has_many :transactions_as_sender, class_name: 'Transaction', inverse_of: :sender, dependent: :destroy
  has_many :transactions_as_receiver, class_name: 'Transaction', inverse_of: :receiver, dependent: :destroy

  def self.sync_with_slack
    Slack.configure do |config|
      config.token = ENV['SLACK_API_KEY']
    end
    client = Slack::Web::Client.new

    all_members = []
    client.users_list do |response|
      all_members.concat(response.members)
    end
    all_members.each do |member|
      name = member.name
      email = member.profile.email
      next unless email

      puts "#{name} #{email}"
      account = Account.find_by(email: email.downcase) || Account.create(name: name, email: email)
      account.slack_member = true
      account.save
    end
  end

  def self.balance
    Account.where(:address_hash.ne => '0x0000000000000000000000000000000000000000').map(&:balance).sum
  end

  def self.with_balance
    all.select { |account| account.balance > 0 }.sort_by { |account| -account.balance }
  end

  def self.with_balance_or_slack_member
    all.select { |account| account.balance > 0 || account.slack_member }.sort_by { |account| -account.balance }
  end

  def balance
    transactions_as_receiver.pluck(:amount).sum - transactions_as_sender.pluck(:amount).sum
  end

  def self.protected_attributes
    %w[admin]
  end

  attr_accessor :password

  before_validation do
    self.password = Account.generate_password(8) unless password || crypted_password
    self.address_hash = address_hash.downcase if address_hash
  end

  validates_uniqueness_of   :address_hash, allow_nil: true
  validates_uniqueness_of   :email, case_sensitive: false, allow_nil: true
  validates_format_of       :email, with: /\A[^@\s]+@[^@\s]+\.[^@\s]+\Z/i, allow_nil: true
  validates_presence_of     :password, if: :password_required
  validates_length_of       :password, within: 4..40, if: :password_required

  def self.admin_fields
    {
      address_hash: :text,
      name: :text,
      email: :email,
      admin: :check_box,
      time_zone: :select,
      link: :url,
      slack_member: :check_box,
      password: { type: :password, new_hint: 'Leave blank to keep existing password' }
    }
  end

  def self.edit_hints
    {
      password: 'Leave blank to keep existing password'
    }
  end

  def firstname
    name.split(' ').first
  end

  def self.time_zones
    [''] + ActiveSupport::TimeZone::MAPPING.keys.sort
  end

  def uid
    id
  end

  def info
    { email: email, name: name }
  end

  def self.authenticate(email, password)
    account = find_by(email: /^#{::Regexp.escape(email)}$/i) if email.present?
    account && account.has_password?(password) ? account : nil
  end

  before_save :encrypt_password, if: :password_required

  def has_password?(password)
    ::BCrypt::Password.new(crypted_password) == password
  end

  def self.generate_password(len)
    chars = ('a'..'z').to_a + ('0'..'9').to_a
    Array.new(len) { chars[rand(chars.size)] }.join
  end

  private

  def encrypt_password
    self.crypted_password = ::BCrypt::Password.create(password)
  end

  def password_required
    crypted_password.blank? || password.present?
  end
end
