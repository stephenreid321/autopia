namespace :transactions do
  task import: :environment do
    Transaction.import
  end
end
