class EthAddress
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :account, index: true

  field :address_hash, type: String

  def self.admin_fields
    {
      address_hash: :text,
      account_id: :lookup
    }
  end
end
