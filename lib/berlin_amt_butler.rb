require "berlin_amt_butler/version"
require 'open-uri'
require 'nokogiri'

module BerlinAmtButler
  # TO RUN:
  # load 'docs/amt_fetcher.rb'

  # Strategie: nach Kreuzberg fahren und dort direkt einen Termin reservieren lassen
  class BuergeramtFetcher
    def url
      'https://service.berlin.de/standorte/buergeraemter/'
    end

    def doc
      @doc ||= Nokogiri::HTML(open(url))
    end

    def all
      @all ||= begin
        doc.css('ul.list li a').map do |link|
          link_url  = link.attributes['href'].value
          link_text = link.text
          {
            text: link_text,
            url:  link_url,
            id:   link_url.delete('^0-9')
          }
        end
      end
    end
  end

  class AvailabilityChecker
    attr_accessor :amt_id
    def initialize(amt_id)
      @amt_id = amt_id
    end

    def name
      doc.css('h1.title').first.text.strip.gsub("Terminvereinbarung\r\nStandort", '')
    end

    def spaces
      @spaces ||= begin
        links.map do |avail_link|
          count = avail_link.attributes['title'].value
          month = avail_link.parent.parent.parent.parent.css('th.month').text.strip
          text  = avail_link.text
          date  = month + " " + text
          {
            count: count,
            date: date
          }
        end
      end
    end

    def summary
      return "." if spaces.size == 0
      res = ["Name: #{name}"]

      if spaces.size > 0
        res << "CHECK here: #{url}"

        spaces.each do |space|
          res << "#{space[:date]} : #{space[:count]}"
        end
        res << " "
      else
        res << "..NONE.."
      end
      res.join("\n")
    end

    def links
      doc.css(' .collapsible-group td.buchbar a')
    end

    def has_slots?
      links.size > 0
    end

    def doc
      @doc ||= Nokogiri::HTML(open(url))
    end

    def anliegen
      120697
    end

    def url
      "https://service.berlin.de/terminvereinbarung/termin/tag.php?termin=1&dienstleister=#{amt_id}&anliegen[]=#{anliegen}&herkunft=1"
    end
  end


  class Runner
    def run
      fetcher = BuergeramtFetcher.new
      fetcher.all.each do |amt|
        check(amt[:id])
      end; nil
    end

    def check(id)
      begin
        checker = AvailabilityChecker.new(id)
        puts checker.summary if checker.has_slots?
      rescue OpenURI::HTTPError => e
        #puts "NOT found for #{id}"
      end
    end
  end
end


