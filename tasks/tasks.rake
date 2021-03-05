namespace :transactions do
  task import: :environment do
    Transaction.import
  end
end

namespace :accounts do
  task sync_with_slack: :environment do
    Account.sync_with_slack
  end

  task sync_with_dao: :environment do
    Account.sync_with_dao
  end
end

namespace :coins do
  task import: :environment do
    Coin.import
  end

  task remote_update: :environment do
    coinships = Coinship.and(:id.in =>
      Coinship.and(starred: true).pluck(:id) + Coinship.and(:tag_id.ne => nil).pluck(:id))
    Coin.and(:id.in => coinships.pluck(:coin_id)).each do |coin|
      puts coin.slug
      coin.remote_update
    end
    coinships.each do |coinship|
      puts "#{coinship.account.name} ~ #{coinship.coin.slug}"
      coinship.remote_update(skip_coin_update: true)
    end
  end
end

namespace :tags do
  task update_holdings: :environment do
    Tag.update_holdings
  end
end
