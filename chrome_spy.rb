#!/usr/bin/env ruby

# This script dumps out interesting aggregate data about your chrome usage.
require 'rubygems'
require 'sqlite3'
require 'active_record'

ActiveRecord::Base.establish_connection({
  :adapter => "sqlite3",
  :database => File.expand_path("~/Library/Application Support/Google/Chrome/Default/History")
})

# If you'd like to see the entire schema...
# puts ActiveRecord::SchemaDumper.dump

module TimestampAccessors
  def timestamp_accessors(*attributes)
    attributes.each do |attr|
      name = attr.to_s

      # use method from http://linuxsleuthing.blogspot.nl/2011/06/decoding-google-chrome-timestamps-in.html
      # to fix time stamps
      define_method(name) {
        raw = read_attribute(name).to_s
        epoch = (raw.to_i / 1000000) -11644473600
        Time.at(epoch)
      }

      define_method(name+'=') { |t|
        write_attribute(name, t.to_i)
      }
    end
  end
end
ActiveRecord::Base.extend(TimestampAccessors)

class Download < ActiveRecord::Base
  # t.string  "full_path",      :limit => nil, :null => false
  # t.string  "url",            :limit => nil, :null => false
  # t.integer "start_time",                    :null => false
  # t.integer "received_bytes",                :null => false
  # t.integer "total_bytes",                   :null => false
  # t.integer "state",                         :null => false

  timestamp_accessors :start_time
end

# join model
class KeywordSearchTerm < ActiveRecord::Base
  # t.integer "keyword_id",                :null => false
  # t.integer "url_id",                    :null => false
  # t.string  "lower_term", :limit => nil, :null => false
  # t.string  "term",       :limit => nil, :null => false
  self.primary_key = :keyword_id
  belongs_to :url
end

class Meta < ActiveRecord::Base
  # t.string "value", :limit => nil
end

class Segment < ActiveRecord::Base
  belongs_to :url
  has_many :segment_usages
end

class SegmentUsage < ActiveRecord::Base
  # t.integer "segment_id",                 :null => false
  # t.integer "time_slot",                  :null => false
  # t.integer "visit_count", :default => 0, :null => false
  self.table_name = "segment_usage"
  belongs_to :segment
  timestamp_accessors :time_slot
end

class Url < ActiveRecord::Base
  # t.string  "url",             :limit => nil
  # t.string  "title",           :limit => nil
  # t.integer "visit_count",                    :default => 0, :null => false  # seems out of sync
  # t.integer "typed_count",                    :default => 0, :null => false
  # t.integer "last_visit_time",                               :null => false
  # t.integer "hidden",                         :default => 0, :null => false
  # t.integer "favicon_id",                     :default => 0, :null => false
  timestamp_accessors :last_visit_time
  has_many :visits, :foreign_key => "url"
end

class VisitSource < ActiveRecord::Base
  self.table_name = "visit_source"
  # t.integer "source", :null => false
end

class Visit < ActiveRecord::Base
  # t.integer "url",                       :null => false
  # t.integer "visit_time",                :null => false
  # t.integer "from_visit" ???
  # t.integer "transition", :default => 0, :null => false
  # t.integer "segment_id"
  # t.boolean "is_indexed"

  timestamp_accessors :visit_time
  belongs_to :url, :foreign_key => 'url'
  belongs_to :segment
end

class ChromeSpy
  class <<self
    def recent_searches
      KeywordSearchTerm.includes('url').order('urls.last_visit_time desc').each { |t| puts t.term }
      nil
    end

    def most_frequent_sites
      Url.order('visit_count desc').limit(5).all.each { |u| puts "visit count: #{u.visit_count} - #{u.url}" }
      nil
    end

    def most_frequently_typed_addresses
      Url.order('typed_count desc').limit(5).all.each { |u| puts "typed count: #{u.typed_count} - #{u.url}" }
      nil
    end

    def recent_downloads
      Download.order('start_time DESC').limit(5).all.each { |d| puts "bytes: #{d.total_bytes} path: #{d.full_path}" }
      nil
    end
  end
end