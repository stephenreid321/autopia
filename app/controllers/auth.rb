Autopia::App.controller do
  get '/auth/failure' do
    flash.now[:error] = '<strong>Hmm.</strong> There was a problem signing you in.'
    erb :sign_in
  end

  get '/sign_out' do
    session.clear
    redirect '/sign_in'
  end

  get '/reset_password' do
    @hide_right_nav = true
    erb :reset_password
  end

  post '/reset_password' do
    if params[:email] && (@account = Account.find_by(email: params[:email].downcase))
      if @account.reset_password!
        flash[:notice] = "A new password was sent to #{@account.email}"
      else
        flash[:error] = 'There was a problem resetting your password.'
      end
    else
      flash[:error] = "There's no account registered under that email address."
    end
    redirect '/sign_in'
  end

  %w[get post].each do |method|
    send(method, '/auth/:provider/callback') do
      account = if env['omniauth.auth']['provider'] == 'account'
                  Account.find(env['omniauth.auth']['uid'])
                else
                  # env['omniauth.auth'].delete('extra')
                  # @provider = Provider.object(env['omniauth.auth']['provider'])
                  # ProviderLink.find_by(provider: @provider.display_name, provider_uid: env['omniauth.auth']['uid']).try(:account)
                  nil
                end
      if current_account # already signed in; attempt to connect
        # if account # someone's already connected
        # flash[:error] = "Someone's already connected to that account!"
        # else # connect; Account never reaches here
        # current_account.provider_links.build(provider: @provider.display_name, provider_uid: env['omniauth.auth']['uid'], omniauth_hash: env['omniauth.auth'])
        # current_account.picture_url = @provider.image.call(env['omniauth.auth']) unless current_account.picture
        # if current_account.save
        #   flash[:notice] = "<i class=\"fa fa-#{@provider.icon}\"></i> Connected!"
        # else
        #   flash[:error] = 'There was an error connecting the account'
        # end
        # end
        redirect '/accounts/edit'
      elsif account # not signed in
        session['account_id'] = account.id.to_s
        flash[:notice] = 'Signed in!'
        if session[:return_to]
          redirect session[:return_to]
        else
          redirect "/u/#{current_account.username}/coins"
        end
      end
    end
  end
end
