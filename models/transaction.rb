class Transaction
  include Mongoid::Document
  include Mongoid::Timestamps

  field :identifier, type: String
  field :tx, type: String
  field :amount, type: BigDecimal
  field :block, type: Integer

  belongs_to :sender, class_name: 'Account', inverse_of: :transactions_as_sender, index: true
  belongs_to :receiver, class_name: 'Account', inverse_of: :transactions_as_receiver, index: true

  def self.admin_fields
    {
      identifier: :text,
      tx: :text,
      amount: :number,
      block: :number,
      sender_id: :lookup,
      receiver_id: :lookup
    }
  end

  validates_uniqueness_of :identifier

  before_validation do
    errors.add(:tx, 'already exists in another block') if (transaction = Transaction.find_by(tx: tx)) && transaction.block != block
  end

  def self.import
    a = Mechanize.new
    items = []

    j = JSON.parse(a.get('https://blockscout.com/poa/xdai/tokens/0xcaE40062a887581A3d1661d0AC2b481c32e3E938/token-transfers?type=JSON').body)

    while j
      items += j['items']
      puts items.count
      break unless j['next_page_path']

      j = JSON.parse(a.get(j['next_page_path'] + '&type=JSON').body)
    end

    items.each do |item|
      h = Nokogiri::HTML(item)
      block = h.search("a[href^='/poa/xdai/blocks']")[0].text.gsub('Block #', '')
      identifier = h.search('[data-identifier-hash]')[0].attr('data-identifier-hash')
      tx = h.search('[data-test=transaction_hash_link]')[0].text
      puts from = h.search('[data-address-hash]')[0].attr('data-address-hash').downcase
      puts to = h.search('[data-address-hash]')[1].attr('data-address-hash').downcase
      sender = Account.find_or_create_by!(address_hash: from)
      receiver = Account.find_or_create_by!(address_hash: to)
      amount = h.search('.tile-title').text.split(' ').first.gsub(',', '')

      puts tx
      create(identifier: identifier, tx: tx, sender: sender, receiver: receiver, amount: amount, block: block)
    end
  end
end
