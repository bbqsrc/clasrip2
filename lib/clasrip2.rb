module Clasrip2

require "mechanize"
require "net/http"
require "mongo"
require "./clasrip2/search-page.rb"

  class Connection
    def initialize(host, port=80)
      @host = host
      @port = port
      connect
    end
    
    def connect
      @conn = Net::HTTP.new(@host, @port)
      @conn.read_timeout = 10
      @conn.start
    end

    def add_headers(response, url)
      response['accept'] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      response['Accept-Charset'] = "ISO-8859-1,utf-8;q=0.7,*;q=0.3"
      response['Cache-Control'] = 'max-age=0'
      response['user-agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.4 (KHTML, like Gecko) Chrome/22.0.1229.94 Safari/537.4"
      response['host'] = "#{@host}"
      response['referer'] = "http://#{@host}#{url}"
      response["origin"] = "http://#{@host}"
      response['connection'] = "keep-alive"
      return response
    end

    def get(url)
      begin
        get = add_headers(Net::HTTP::Get.new(url), url)
        return @conn.request(get)
      rescue
        connect
        retry
      end
    end
    
    def post(url, data)
      begin
        post = add_headers(Net::HTTP::Post.new(url), url)
        post['content-type'] = "application/x-www-form-urlencoded"
        post.set_form_data(data)
        return @conn.request(post)
      rescue
        connect
        retry
      end
    end
  end

  class Scraper
    @@host = "www.classification.gov.au"
    
    def run(from=nil, to=nil)
      connection = Mongo::Connection.new
      db = connection.db("classification")
      coll = db.collection("records")

      conn = Clasrip2::Connection.new(@@host)
      search = SearchPage.new(conn)
      c = 0
      page = search.query_date_period(from, to)
      print("Starting at #{from.strftime('%Y-%m-%d')}, ending at #{to.strftime('%Y-%m-%d')}\n")
      while page != nil
        classifications = page.get_classifications
        classifications.each do |cls|
          c += 1
          coll.insert(cls)
          print("[#{c}/#{page.total_results}] #{cls['date_of_classification']}: #{cls['title']} (#{cls['classification']})\n")
        end
        page = page.next_page
      end
      
    end
  end

  class Verifier
    @@host = "www.classification.gov.au"
    @@pass = "\u2713"
    @@fail = "\u00D7"
    
    def run(from=nil, to=nil)
      connection = Mongo::Connection.new
      db = connection.db("classification")
      coll = db.collection("records")

      conn = Clasrip2::Connection.new(@@host)
      search = SearchPage.new(conn)
      c = 0
      page = search.query_date_period(from, to)
      print "Verification starting at #{from.strftime('%Y-%m-%d')}, ending at #{to.strftime('%Y-%m-%d')}\n"
      
      while page != nil
        classifications = page.to_hashes
        classifications.each do |cls|
          c += 1
          result = coll.find(cls).to_a.length
          if result == 1
            print "\r#{@@pass} [#{c}/#{page.total_results}] #{cls['date_of_classification']}: #{cls['title']} (Category: #{cls['category']}) (Media: #{cls['medium']})"
          elsif result > 1
            print "#{@@fail} [#{c}/#{page.total_results}] #{cls['date_of_classification']}: #{cls['title']} (Category: #{cls['category']}) (Media: #{cls['medium']}) - DUPE [#{result}]\n"
          elsif result == 0
            print "#{@@fail} [#{c}/#{page.total_results}] #{cls['date_of_classification']}: #{cls['title']} (Category: #{cls['category']}) (Media: #{cls['medium']}) - MISSING [#{result}]\n"
          end
        end
        page = page.next_page
      end
    end
  end

end

scr = Clasrip2::Scraper.new
scr.run(Date.parse(ARGV[0]), Date.parse(ARGV[1]))
