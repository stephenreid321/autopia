Autopia::App.helpers do
  def timeago(x)
    %(<abbr data-toggle="tooltip" class="timeago" title="#{x.iso8601}">#{x}</abbr>)
  end

  def md(slug)
    text = open("#{Padrino.root}/app/markdown/#{slug}.md").read.force_encoding('utf-8')
    text = text.gsub(/\A---(.|\n)*?---/, '')
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true, fenced_code_blocks: true)
    markdown.render(text)
  end

  def front_matter(slug)
    text = open("#{Padrino.root}/app/markdown/#{slug}.md").read.force_encoding('utf-8')
    FrontMatterParser::Parser.new(:md).call(text)
  end

  def cp(slug)
    cache(slug, expires: 6.hours.to_i) { ; partial :"#{slug}"; }
  end

  def current_account
    @current_account ||= Account.find(session[:account_id]) if session[:account_id]
  end

  def sign_in_required!
    halt(403) unless current_account
  end

  def build_registered
    responses = CSV.parse(open(Padrino.root('data', 'eth-email.csv')))
    registered = {}
    responses.each_with_index do |row, i|
      next if i == 0

      eth = row[0].downcase.strip
      email = row[1].downcase.strip
      registered[eth] = email
    end
    registered
  end

  def build_balances
    a = Mechanize.new
    items = []

    j = JSON.parse(a.get('https://blockscout.com/poa/xdai/tokens/0xcaE40062a887581A3d1661d0AC2b481c32e3E938/token-transfers?type=JSON').body)

    while j
      items += j['items']
      puts items.count
      break unless j['next_page_path']

      j = JSON.parse(a.get(j['next_page_path'] + '&type=JSON').body)
    end

    balances = {}

    items.each do |item|
      h = Nokogiri::HTML(item)
      from = h.search('[data-address-hash]')[0].attr('data-address-hash')
      to = h.search('[data-address-hash]')[1].attr('data-address-hash')
      tokens = h.search('.tile-title').text.split(' ').first.gsub(',', '').to_f

      balances[from] = 0 unless balances[from]
      balances[to] = 0 unless balances[to]
      balances[from] -= tokens
      balances[to] += tokens
    end

    balances = balances.select { |_k, v| v > 0 }.sort_by { |_k, v| -v }
  end
end
