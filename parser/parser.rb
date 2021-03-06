#! /usr/bin/env ruby
require 'xml'
# require 'bzip2'


class WikiDump
  include Enumerable

  attr_reader :reader

  def initialize(io)
    @reader = XML::Reader.io io
  end

  def each
    while reader.read
      if page_node?
        yield reader.read_outer_xml
      end
    end
  end

  private :reader

  def page_node?
    reader.node_type == XML::Node::ELEMENT_NODE and reader.name == "page" and reader.depth == 1
  end
end


class Page
  LINK_REGEX = /\[\[[^\]]+\]\]/
  attr_reader :reader, :title, :text

  def initialize(xml)
    @reader = XML::Reader.string xml
    @title = @text = nil
    parse
  end

  def links
    return text.scan(LINK_REGEX).map{ |l| WikiLink.new l }
  end

  private :reader

  def parse
    while reader.read
      if reader.node_type == XML::Node::ELEMENT_NODE
        if reader.name == "title"
          @title = reader.read_string
        elsif reader.name == "text"
          @text = reader.read_string
        end
      end
    end
  end

  class WikiLink
    def initialize(link)
      @link = link
    end
  end
end


class Application
  attr_reader :dump_file

  def initialize(dump_file)
    @dump_file = dump_file
  end

  def run
    # puts dump.lazy.map{|x| Page.new x}.find{|p| p.title == "International Atomic Time"}.text

    dump.lazy.take(100).map{|x| Page.new x}.each do |page|
      puts "#{page.title} #{page.links.length}"
    end
  end

  private :dump_file

  def dump
    WikiDump.new xml
  end

  def xml
    #Bzip2::Reader.new(File.new(dump_file))
    File.new(dump_file)
  end
end


# Oops, my python is showing
if __FILE__ == $0
  Application.new(ARGV[0] || STDIN.fileno).run
end
