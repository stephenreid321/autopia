Autopia::App.controller do
  before do
    halt 200 unless admin?
    @virtual_tags = %w[starred tagged wallets elsewhere uniswap sushiswap defi-pulse 24h 7d market-cap-24h top-100 top-100-less-tagged starred-less-tagged holding-less-starred starred-less-holding]
  end

  get '/u/:username' do
    redirect "/u/#{params[:username]}/tags/starred"
  end

  get '/u/:username/coins' do
    redirect "/u/#{params[:username]}/tags/starred"
  end

  get '/u/:username/tags' do
    @account = Account.find_by(username: params[:username]) || not_found
    @account.tags.update_holdings
    erb :'coins/tags'
  end

  get '/u/:username/tags/:tag' do
    @title = params[:tag]
    @account = Account.find_by(username: params[:username]) || not_found
    if params[:tag] == 'uniswap'
      agent = Mechanize.new
      @uniswap = []
      Coin.and(:uniswap_volume.ne => nil).set(uniswap_volume: nil)
      JSON.parse(agent.get('https://api.coingecko.com/api/v3/exchanges/uniswap').body)['tickers'].each do |ticker|
        if coin = Coin.find_by(slug: ticker['coin_id'])
          coin.update_attribute(:uniswap_volume, ticker['converted_volume']['eth'])
        end
        @uniswap << ticker['coin_id']
      end
    elsif params[:tag] == 'sushiswap'
      agent = Mechanize.new
      @sushiswap = []
      Coin.and(:sushiswap_volume.ne => nil).set(sushiswap_volume: nil)
      JSON.parse(agent.get('https://api.coingecko.com/api/v3/exchanges/sushiswap').body)['tickers'].each do |ticker|
        if coin = Coin.find_by(slug: ticker['coin_id'])
          coin.update_attribute(:sushiswap_volume, ticker['converted_volume']['eth'])
        end
        @sushiswap << ticker['coin_id']
      end
    elsif params[:tag] == 'defi-pulse'
      agent = Mechanize.new
      @defi_pulse = []
      Coin.and(:tvl.ne => nil).set(tvl: nil)
      JSON.parse(agent.get('https://defipulse.com/').search('#__NEXT_DATA__').inner_html)['props']['initialState']['coin']['projects'].each do |project|
        if coin = Coin.find_by(defi_pulse_name: project['name'])
          coin.update_attribute(:tvl, project['value']['tvl']['ETH']['value'])
          @defi_pulse << coin.slug
        end
      end
    end
    @uniswap_slugs = Coin.and(:uniswap_volume.ne => nil).order('uniswap_volume desc').pluck(:slug)
    @sushiswap_slugs = Coin.and(:sushiswap_volume.ne => nil).order('sushiswap_volume desc').pluck(:slug)
    @tvl_slugs = Coin.and(:tvl.ne => nil).order('tvl desc').pluck(:slug)
    erb :'coins/coins'
  end

  get '/u/:username/tags/:tag/table' do
    @account = Account.find_by(username: params[:username]) || not_found
    partial :'coins/coin_table', locals: { coins: Coin.and(
      :id.in => @account.coinships.and(tag: @account.tags.find_by(name: params[:tag])).pluck(:coin_id)
    ).order('price_change_percentage_24h_in_currency desc') }
  end

  get '/u/:username/coins/:slug' do
    @account = Account.find_by(username: params[:username]) || not_found
    coin = Coin.find_by(slug: params[:slug])
    coin.remote_update
    partial :'coins/coin', locals: { coin: coin }
  end

  # sign_in_required

  get '/coins/add_tag/:tag' do
    sign_in_required!
    tag = current_account.tags.find_or_create_by(name: params[:tag].parameterize)
    redirect "/u/#{current_account.username}/tags/#{tag.name}"
  end

  get '/coins/delete_tag/:tag' do
    sign_in_required!
    tag = current_account.tags.find_by(name: params[:tag]).destroy
    redirect "/u/#{current_account.username}/tags"
  end

  get '/coins/rename_tag/:tag/:new' do
    sign_in_required!
    tag = current_account.tags.find_by(name: params[:tag])
    tag.update_attribute(:name, params[:new].parameterize)
    redirect "/u/#{current_account.username}/tags/#{tag.name}"
  end

  post '/coins/tag/:tag' do
    sign_in_required!
    if coin = (Coin.symbol(params[:symbol]) || Coin.find_by(slug: params[:symbol]))
      coinship = current_account.coinships.find_or_create_by(coin: coin)
      coinship.tag = current_account.tags.find_by(name: params[:tag])
      coinship.save
    end
    current_account.tags.update_holdings
    200
  end

  get '/coins/:coin_id/hide' do
    sign_in_required!
    coinship = current_account.coinships.find_by(coin: params[:coin_id])
    coinship.try(:destroy)
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

  get '/holding_change_notifications' do
    partial :'coins/holding_change_notifications'
  end

  post '/holding_change_notifications' do
    sign_in_required!
    current_account.update_attribute(:holding_change_notifications, params[:holding_change_notifications])
    200
  end
end
