require 'mechanize'
require 'json'

graphql = %{
  {
   pair(id: "0xccace6772a98d8a3da115b63e816e500a12aad9a"){
       token0 {
         id
         symbol
         name
         derivedETH
       }
       token1 {
         id
         symbol
         name
         derivedETH
       }
       reserve0
       reserve1
       reserveUSD
       trackedReserveETH
       token0Price
       token1Price
       volumeUSD
       txCount
   }
  }
}.gsub("\n", ' ').gsub('"', '\\"')

agent = Mechanize.new
response = agent.post 'https://api.thegraph.com/subgraphs/name/1hive/uniswap-v2', %({"query":"#{graphql}"}), { 'Content-Type' => 'application/json' }
puts JSON.parse(response.body)
