Autopia::App.controller do
  get '/accounts/edit' do
    sign_in_required!
    @account = current_account
    erb :'accounts/edit'
  end

  post '/accounts/edit' do
    sign_in_required!
    @account = current_account
    if @account.update_attributes(params[:account])
      flash[:notice] = 'Your account was updated successfully.'
      redirect '/accounts/edit'
    else
      erb :'accounts/edit'
    end
  end

  post '/eth_addresses/add' do
    sign_in_required!
    current_account.eth_addresses.create(address_hash: params[:eth_address])
    redirect '/accounts/edit#wallet_addresses'
  end

  get '/eth_addresses/delete/:eth_address' do
    sign_in_required!
    current_account.eth_addresses.find_by(address_hash: params[:eth_address]).destroy
    redirect '/accounts/edit#wallet_addresses'
  end
end
