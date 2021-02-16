Autopia::App.controller do
  before do
    @virtual_tags = %w[starred watching watching-less-core uniswap sushiswap defi-pulse 24h 7d market-cap-24h top-100 top-100-less-tagged starred-less-tagged]
  end

  get '/u/:account_id/coins' do
    redirect "/u/#{params[:account_id]}/tags/holding"
  end

  get '/u/:account_id/tags' do
    @account = Account.find(params[:account_id])
    @account.tags.update_holdings
    erb :'coins/tags'
  end

  get '/u/:account_id/tags/:tag' do
    @account = Account.find(params[:account_id])
    if params[:tag] == 'uniswap'
      agent = Mechanize.new
      @uniswap = []
      Coin.where(:uniswap_volume.ne => nil).set(uniswap_volume: nil)
      JSON.parse(agent.get('https://api.coingecko.com/api/v3/exchanges/uniswap').body)['tickers'].each do |ticker|
        if coin = Coin.find_by(slug: ticker['coin_id'])
          coin.update_attribute(:uniswap_volume, ticker['converted_volume']['eth'])
        end
        @uniswap << ticker['coin_id']
      end
    elsif params[:tag] == 'sushiswap'
      agent = Mechanize.new
      @sushiswap = []
      Coin.where(:sushiswap_volume.ne => nil).set(sushiswap_volume: nil)
      JSON.parse(agent.get('https://api.coingecko.com/api/v3/exchanges/sushiswap').body)['tickers'].each do |ticker|
        if coin = Coin.find_by(slug: ticker['coin_id'])
          coin.update_attribute(:sushiswap_volume, ticker['converted_volume']['eth'])
        end
        @sushiswap << ticker['coin_id']
      end
    elsif params[:tag] == 'defi-pulse'
      agent = Mechanize.new
      @defi_pulse = []
      Coin.where(:tvl.ne => nil).set(tvl: nil)
      JSON.parse(agent.get('https://defipulse.com/').search('#__NEXT_DATA__').inner_html)['props']['initialState']['coin']['projects'].each do |project|
        if coin = Coin.find_by(defi_pulse_name: project['name'])
          coin.update_attribute(:tvl, project['value']['tvl']['ETH']['value'])
          @defi_pulse << coin.slug
        end
      end
    end
    @uniswap_slugs = Coin.where(:uniswap_volume.ne => nil).order('uniswap_volume desc').pluck(:slug)
    @sushiswap_slugs = Coin.where(:sushiswap_volume.ne => nil).order('sushiswap_volume desc').pluck(:slug)
    @tvl_slugs = Coin.where(:tvl.ne => nil).order('tvl desc').pluck(:slug)
    erb :'coins/coins'
  end

  get '/u/:account_id/tags/:tag/table' do
    @account = Account.find(params[:account_id])
    partial :'coins/coin_table', locals: { coins: Coin.where(
      :id.in => @account.coinships.where(tag: @account.tags.find_by(name: params[:tag])).pluck(:coin_id)
    ).order('price_change_percentage_24h_in_currency desc') }
  end

  get '/u/:account_id/coins/:slug' do
    @account = Account.find(params[:account_id])
    coin = Coin.find_by(slug: params[:slug])
    coin.remote_update
    partial :'coins/coin', locals: { coin: coin }
  end

  # sign_in_required

  post '/coins/tag/:tag' do
    sign_in_required!
    if coin = Coin.symbol(params[:symbol])
      coinship = current_account.coinships.find_or_create_by(coin: coin)
      coinship.tag = current_account.tags.find_or_create_by(name: params[:tag])
      coinship.save
    end
    current_account.tags.update_holdings
    200
  end

  get '/coins/:coin_id/hide' do
    sign_in_required!
    coinship = current_account.coinships.find_or_create_by(coin: params[:coin_id])
    coinship.update_attribute(:tag_id, nil)
    current_account.tags.update_holdings
    200
  end

  get '/coins/:coin_id/star' do
    sign_in_required!
    coinship = current_account.coinships.find_or_create_by(coin: params[:coin_id])
    coinship.update_attribute(:starred, true)
    coinship.remote_update
    200
  end

  get '/coins/:coin_id/unstar' do
    sign_in_required!
    coinship = current_account.coinships.find_or_create_by(coin: params[:coin_id])
    coinship.update_attribute(:starred, nil)
    coinship.remote_update
    200
  end

  post '/coins/:coin_id/units_elsewhere' do
    sign_in_required!
    coinship = current_account.coinships.find_or_create_by(coin: params[:coin_id])
    coinship.update_attribute(:units_elsewhere, params[:units_elsewhere])
    200
  end

  post '/coins/:coin_id/market_cap_rank_prediction' do
    sign_in_required!
    coinship = current_account.coinships.find_or_create_by(coin: params[:coin_id])
    coinship.update_attribute(:market_cap_rank_prediction, params[:p])
    200
  end

  post '/coins/:coin_id/market_cap_rank_prediction_conviction' do
    sign_in_required!
    coinship = current_account.coinships.find_or_create_by(coin: params[:coin_id])
    coinship.update_attribute(:market_cap_rank_prediction_conviction, params[:p])
    200
  end
end
