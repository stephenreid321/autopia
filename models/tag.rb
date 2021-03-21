class Tag
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :holding, type: Float

  before_validation do
    self.holding = coinships.sum { |coinship| coinship.holding }
  end

  belongs_to :account, index: true
  has_many :coinships, dependent: :nullify
  def coins
    Coin.and(:id.in => coinships.pluck(:coin_id))
  end

  def self.admin_fields
    {
      name: :text,
      account_id: :lookup,
      holding: :number
    }
  end

  def self.update_holdings
    all.each(&:update_holding)
  end

  def update_holding
    update_attribute(:holding, coinships.sum { |coinship| coinship.holding })
  end

  def self.holding
    all.sum { |tag| tag.holding }
  end

  %w[1h 24h 7d].each do |p|
    define_method :"price_change_percentage_#{p}_in_currency" do
      a = coins.map(&:"price_change_percentage_#{p}_in_currency").compact
      if (n = a.count) > 0
        a.sum / n
      end
    end
  end

  def market_cap_change_percentage_24h
    a = coins.map(&:market_cap_change_percentage_24h).compact
    if (n = a.count) > 0
      a.sum / n
    end
  end

  def background_color
    tags = account.tags.order('holding desc').and(:holding.gt => 0)
    i = tags.pluck(:id).index(id)
    i = (tags.count - 1) - i if i.odd?
    i && !tags.empty? ? '#8747E6'.paint.spin(0 - (i.to_f / (tags.count - 1)) * (360 - (360 / tags.count))).lighten(10) : '#666666'
  rescue StandardError
    '#666666'
  end
end
