require "nokogiri"
require "date"

class ClassificationPage
  def initialize(html)
    @html = Nokogiri::HTML(html)
  end
  
  def to_hash
    out = {}

    title = @html.at_css(".ncd-title-container .ncd-title").text.strip
    match = /^(.*?)\s*(?:\((.*?)\))?$/.match(title)
    out['title'] = match[1]
    out['medium'] = match[2].nil? ? "" : match[2]
    
    @html.css(".ncd-view-item tr").each do |row|
      key = row.css(".ncd-field-title").text.strip
      key = key.encode("UTF-8") unless key.valid_encoding?
      key = key.strip.gsub("\u00A0", "") if key.valid_encoding?
      key = key.gsub(" ", "_").downcase
      next if key == ""
     
      value = row.css(".ncd-field-value").text.strip
      value = value.encode("UTF-8") unless value.valid_encoding?
      value = value.strip.gsub("\u00A0", "") if value.valid_encoding?
      
      if key == "date_of_classification"
        value = Date.parse(value).strftime("%Y-%m-%d")
      end

      out[key] = value
    end
    return out
  end
end
