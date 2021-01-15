class TheGraph
  def self.query(graph, query)
    agent = Mechanize.new
    response = agent.post "https://api.thegraph.com/subgraphs/name/#{graph}", %({"query":"#{query.gsub("\n", ' ').gsub('"', '\\"')}"}), { 'Content-Type' => 'application/json' }
    JSON.parse(response.body)
  end
end
