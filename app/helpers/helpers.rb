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

  def aut(h: '0.75em', va: 'baseline', c: 'black')
    %(<img src="/images/aut#{'-white' if c == 'white'}.png" style="vertical-align: #{va}; height: #{h}">)
  end

  def xdai(h: '0.75em', va: 'baseline')
    %(<img src="/images/xdai.png" style="vertical-align: #{va}; height: #{h}">)
  end

  def tag_badge(tag, account: tag.try(:account), html_tag: 'a')
    if tag
      if tag.is_a?(Tag)
        name = tag.name
        bg = "background-color: #{tag.background_color}"
        c = ''
        s = ''
      else
        name = tag
        bg = 'background: none'
        c = 'text-white'
        s = 'font-weight: 500'
      end
      %(<#{html_tag} href="/u/#{account.id}/tags/#{name}" class="badge badge-secondary #{c}" style="#{bg}; color: white; #{s}">#{name}</#{html_tag}>)
    end
  end
end
