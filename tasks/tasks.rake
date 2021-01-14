namespace :transactions do
  task import: :environment do
    Transaction.import
  end
end

namespace :accounts do
  task sync_with_slack: :environment do
    Account.sync_with_slack
  end
end
