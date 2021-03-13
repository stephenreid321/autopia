class Coinship
  include Mongoid::Document
  include Mongoid::Timestamps

  field :market_cap_rank_prediction, type: Integer
  field :market_cap_rank_prediction_conviction, type: Float
  field :starred, type: Boolean
  field :units, type: Float
  field :units_elsewhere, type: String

  belongs_to :account
  belongs_to :coin
  belongs_to :tag, optional: true

  validates_uniqueness_of :coin, scope: :account

  def self.admin_fields
    {
      account_id: :lookup,
      coin_id: :lookup,
      tag_id: :lookup,
      units: :number,
      units_elsewhere: :text,
      market_cap_rank_prediction: :number,
      market_cap_rank_prediction_conviction: :number,
      starred: :check_box
    }
  end

  after_save do
    if account.holding_change_notifications
      units_before = units
      units_after = units
      if changes['units']
        units_before = changes['units'][0]
        units_after = changes['units'][1]
      end
      units_elsewhere_sum_before = units_elsewhere_sum
      units_elsewhere_sum_after = units_elsewhere_sum
      if changes['units_elsewhere']
        units_elsewhere_sum_before = Coinship.units_elsewhere_sum(changes['units_elsewhere'][0])
        units_elsewhere_sum_after = Coinship.units_elsewhere_sum(changes['units_elsewhere'][1])
      end
      holding_before = (units_before || 0) + (units_elsewhere_sum_before || 0)
      holding_after = (units_after || 0) + (units_elsewhere_sum_after || 0)
      holding_change = holding_after - holding_before
      holding_percentage_change = (100 * holding_change / holding_before).round(1)
      if holding_percentage_change.abs >= 1
        message = if holding_percentage_change.infinite?
                    "<@#{account.slack_id}> bought a fresh batch of <https://www.coingecko.com/en/coins/#{coin.slug}|#{coin.symbol}> https://autopia.co/u/#{account.username}"
                  else
                    "<@#{account.slack_id}>'s <https://www.coingecko.com/en/coins/#{coin.slug}|#{coin.symbol}> holding changed by #{'+' if holding_percentage_change.positive?}#{holding_percentage_change}% https://autopia.co/u/#{account.username}"
                  end
        if Padrino.env == :production
          Slack.configure do |config|
            config.token = ENV['SLACK_API_KEY']
          end
          client = Slack::Web::Client.new
          client.chat_postMessage(
            username: 'Autopia',
            channel: '#crypto-moves',
            icon_url: 'https://autopia.co/images/autopia-200-200.png',
            text: message
          )
        end
      end
    end
  end

  def market_cap_at_predicted_rank
    if (p = market_cap_rank_prediction)
      mc = nil
      until mc
        mc = Coin.find_by(market_cap_rank: p).try(:market_cap)
        p += 1
        break if p > market_cap_rank_prediction + 5
      end
      mc
    end
  end

  def market_cap_change_prediction
    (market_cap_at_predicted_rank / coin.market_cap) * (market_cap_rank_prediction_conviction || 1) if market_cap_at_predicted_rank && coin.market_cap && (coin.market_cap > 0)
  end

  def self.units_elsewhere_sum(units_elsewhere)
    if units_elsewhere
      units_elsewhere.split(' ').map do |x|
        begin
        Float(x.gsub(',', ''))
        rescue StandardError
          nil
      end
      end.compact.sum
    else
      0
    end
  end

  def units_elsewhere_sum
    Coinship.units_elsewhere_sum(units_elsewhere)
  end

  def all_units
    (units || 0) + (units_elsewhere_sum || 0)
  end

  def holding
    (all_units || 0) * (coin.current_price || 0)
  end

  def remote_update(skip_coin_update: nil)
    coin.remote_update unless skip_coin_update

    agent = Mechanize.new
    if starred
      u = 0

      begin
        if coin.platform == 'ethereum'
          account.eth_address_hashes.each do |a|
            u += JSON.parse(agent.get("https://api.etherscan.io/api?module=account&action=tokenbalance&contractaddress=#{coin.contract_address}&address=#{a}&tag=latest&apikey=#{ENV['ETHERSCAN_API_KEY']}").body)['result'].to_i / 10**(coin.decimals || 18).to_f
          end
        elsif coin.platform == 'binance-smart-chain'
          account.eth_address_hashes.each do |a|
            u += JSON.parse(agent.get("https://api.bscscan.com/api?module=account&action=tokenbalance&contractaddress=#{coin.contract_address}&address=#{a}&tag=latest&apikey=#{ENV['BSCSCAN_API_KEY']}").body)['result'].to_i / 10**(coin.decimals || 18).to_f
          end
        elsif coin.symbol == 'ETH'
          account.eth_address_hashes.each do |a|
            u += JSON.parse(agent.get("https://api.etherscan.io/api?module=account&action=balance&address=#{a}&tag=latest&apikey=#{ENV['ETHERSCAN_API_KEY']}").body)['result'].to_i / 10**(coin.decimals || 18).to_f
          end
        elsif coin.symbol == 'BNB'
          account.eth_address_hashes.each do |a|
            u += JSON.parse(agent.get("https://api.bscscan.io/api?module=account&action=balance&address=#{a}&tag=latest&apikey=#{ENV['BSCSCAN_API_KEY']}").body)['result'].to_i / 10**(coin.decimals || 18).to_f
          end
        elsif account.binance_api_key && account.binance_api_secret
          client = Binance::Client::REST.new api_key: account.binance_api_key, secret_key: account.binance_api_secret
          balances = client.account_info['balances']
          bc = balances.find do |b|
            b['asset'] == coin.symbol
          end
          u += (bc['free'].to_f + bc['locked'].to_f) if bc
        end
      rescue StandardError => e
        Airbrake.notify(e)
        return
      end

      self.units = u
    else
      self.units = nil
    end
    save!
  end
end
