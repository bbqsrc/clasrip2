require "mechanize"
require "./clasrip2/result-page.rb"

class SearchPage
  @@search_url = "/Pages/Search.aspx"

  def initialize(conn)
    @conn = conn
    search_page = @conn.get(@@search_url)
    @html = Nokogiri::HTML(search_page.read_body)
  end

  def query_date_period(from_date=nil, to_date=nil)
    raise Exception.new("A from_date or to_date is required") if from_date == nil and to_date == nil
    @html.at_css('[id*=DateFromTextbox]')['value'] = from_date.strftime("%Y-%m-%d") if from_date
    @html.at_css('[id*=DateToTextbox]')['value'] = to_date.strftime("%Y-%m-%d") if to_date
    submit
  end

  def query_single_day(date)
    @html.at_css('[id*=DateFromTextbox]')['value'] = (date - 1).strftime("%Y-%m-%d")
    @html.at_css('[id*=DateToTextbox]')['value'] = (date + 1).strftime("%Y-%m-%d")
    submit
  end

  private
  def submit
    form = Mechanize::Form.new(@html.at_css('form'))
    prefix = @html.at_css('[id*=DateToTextbox]')['name'].sub("DateToTextbox", "")
    query = Hash[form.build_query]
    query["#{prefix}SearchButton"] = ''
    query["#{prefix}ResultsTable$ResultsSortSelector$SortDateOldest$AccessibleLink"] = "date+(oldest)"
    query[@html.at_css('[id*=RestrictedCheckbox]')['name']] = 'on'

    response = @conn.post(@@search_url, query)
    
    # OLDEST TIME
    url = response['location']
    response = @conn.get(url)

    html = Nokogiri::HTML(response.read_body)
    form = Mechanize::Form.new(html.at_css('form'))
    query = Hash[form.build_query]
    query[html.at_css("[name*='ResultsTable$ResultsSortSelector$SortDateOldest$AccessibleLink']")['name']] = "date+(oldest)"
    return ResultPage.new(@conn.post(url, query).read_body, url, @conn)
  end
end
