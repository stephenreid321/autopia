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
  field :slack_id, type: String
  field :dao_shares, type: Integer
  field :dao_loot, type: Integer
  field :binance_api_key, type: String
  field :binance_api_secret, type: String
  field :price_factor, type: Integer
  field :hide_total, type: Boolean

  def self.admin_fields
    {
      address_hash: :text,
      email: :email,
      password: :password,
      name: :text,
      admin: :check_box,
      hide_total: :check_box,
      time_zone: :select,
      link: :url,
      slack_id: :text,
      dao_shares: :number,
      dao_loot: :number,
      price_factor: :number,
      binance_api_key: :text,
      binance_api_secret: :text,
      eth_addresses: :collection,
      coinships: :collection,
      tags: :collection
    }
  end

  def self.human_attribute_name(attr, options = {})
    {
      address_hash: 'Primary address',
      dao_shares: 'DAO shares',
      dao_loot: 'DAO loot',
      slack_id: 'Slack user ID'
    }[attr.to_sym] || super
  end

  has_many :transactions_as_sender, class_name: 'Transaction', inverse_of: :sender, dependent: :destroy
  has_many :transactions_as_receiver, class_name: 'Transaction', inverse_of: :receiver, dependent: :destroy

  has_many :coinships, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :eth_addresses, dependent: :destroy

  def eth_address_hashes
    eth_addresses.empty? ? [address_hash] : eth_addresses.pluck(:address_hash)
  end

  def self.sync_with_dao
    Account.all.set(dao_shares: nil, dao_loot: nil)

    @members = TheGraph.query('odyssy-automaton/daohaus-xdai', %{
          {
            members(where: {molochAddress: "0x80de9a508443c68e825f683f9ebd2659600a678e"}) {
              id
              memberAddress
              shares
              loot
            }
          }
        })
    @members['data']['members'].each do |member|
      account = Account.find_by(address_hash: member['memberAddress']) || Account.create(address_hash: member['memberAddress'])
      account.dao_shares = member['shares']
      account.dao_loot = member['loot']
      account.save
    end
  end

  def self.sync_with_slack
    Account.all.set(slack_id: nil)

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
      next if !email || member.is_invited_user || member.deleted

      puts "#{name} #{email}"
      account = Account.find_by(email: email.downcase) || Account.create(email: email)
      account.name = name
      account.slack_id = member.id
      account.save
    end
  end

  def self.balance
    Account.where(:address_hash.ne => '0x0000000000000000000000000000000000000000').map(&:balance).sum
  end

  def self.with_balance
    all.select { |account| account.balance > 0 }.sort_by { |account| -account.balance }
  end

  def self.interesting
    all.select { |account| account.balance > 0 || account.slack_id || account.dao_shares && account.dao_shares > 0 || account.dao_loot && account.dao_loot > 0 }.sort_by { |account| -account.balance }
  end

  def balance
    transactions_as_receiver.pluck(:amount).sum - transactions_as_sender.pluck(:amount).sum
  end

  def balance_xdai(xdai_per_aut)
    balance * xdai_per_aut
  end

  def self.protected_attributes
    %w[admin]
  end

  def short_hash
    "#{address_hash[0..4]}&hellip;#{address_hash[-2..-1]}" if address_hash
  end

  attr_accessor :password

  before_validation do
    self.password = Account.generate_password(8) unless password || crypted_password
    self.address_hash = address_hash.downcase if address_hash
    self.price_factor = rand(100) unless price_factor
    self.dao_shares = nil if dao_shares && dao_shares.zero?
    self.dao_loot = nil if dao_loot && dao_loot.zero?
  end

  validates_uniqueness_of   :address_hash, allow_nil: true
  validates_uniqueness_of   :email, case_sensitive: false, allow_nil: true
  validates_format_of       :email, with: /\A[^@\s]+@[^@\s]+\.[^@\s]+\Z/i, allow_nil: true
  validates_presence_of     :password, if: :password_required
  validates_length_of       :password, within: 4..40, if: :password_required

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

  def reset_password!
    self.password = Account.generate_password(8)
    if save
      mail = Mail.new
      mail.to = email
      mail.from = 'team@autopia.co'
      mail.subject = "New password for #{ENV['BASE_URI']}"
      mail.body = "Hi #{firstname},\n\nSomeone (hopefully you) requested a new password for #{ENV['BASE_URI']}.\n\nYour new password is: #{password}\n\nYou can sign in at #{ENV['BASE_URI']}/sign_in."
      mail.deliver
    else
      false
    end
  end

  private

  def encrypt_password
    self.crypted_password = ::BCrypt::Password.create(password)
  end

  def password_required
    crypted_password.blank? || password.present?
  end
end
