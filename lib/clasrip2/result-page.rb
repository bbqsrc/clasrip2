require "mechanize"
require "./clasrip2/classification-page.rb"

class ResultPage
  def initialize(html, url, conn)
    @conn = conn 
    @html = Nokogiri::HTML(html)
    @url = url 
    @form = Mechanize::Form.new(@html.at_css('form'))
  end

  def total_results
    if @total.nil?
      @total = @html.at_css("[id*=TotalRowsLabel]").text.to_i
    end
    return @total
  end

  def next_page
    js_mess = @html.css(".pager-ctl a").last['href']
    return nil if js_mess.nil?
    js_mess.sub!("javascript:__doPostBack('", "")
    js_mess.sub!("','')", "")

    query = Hash[@form.build_query]
    query["__EVENTTARGET"] = js_mess
    return ResultPage.new(@conn.post(@url, query).read_body, @url, @conn)
  end

  def classification_buttons
    return @html.css(".ncd-results-table table input[type='submit']")
  end

  def get_classification(node)
    query = Hash[@form.build_query]
    query[node['name']] = node['value']
    response = @conn.get(@conn.post(@url, query)['location']).read_body
    return ClassificationPage.new(response)
  end

  def get_classifications
    out = []
    classification_buttons.each do |button|
      out.push(get_classification(button).to_hash)
    end
    return out
  end

  def to_hashes
    out = []
    rows = @html.css(".ncd-results-table > table tr")
    rows.each do |row|
      title = row.at_css("[id*=ScriptLink]")
      next if title.nil?
      
      o = {}
      o["title"] = title.text.strip.gsub("\u00A0", "")
      o["date_of_classification"] = row.at_css(".item-date").text.strip.gsub("\u00A0", "")
      o["category"] = row.at_css(".item-category").text.strip.gsub("\u00A0", "")
      
      medium = row.at_css('.media-type')
      unless medium.nil? 
        x = /\((.*?)\)/.match(medium.text.strip.gsub("\u00A0", ""))
        medium = x[1] if x.length > 0
      end

      o["medium"] = medium unless medium.nil?
      out.push o
    end
    
    return out
  end
end
