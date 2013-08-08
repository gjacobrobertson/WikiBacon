#! /usr/bin/env ruby
require 'xml'
require 'neography'


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
    return text.scan(LINK_REGEX).map{ |l| WikiLink.new l }.select{|l| l.valid?}.uniq
  end

  def save
    page_node = Application.neo.create_unique_node 'pages', 'title', @title, :title => @title
    create_relationships page_node, create_nodes
  end

  private :reader

  def create_nodes
    batch = links.map do |link|
      link_title = link.title
      [:create_unique_node, 'pages', 'title', link_title, {:title => link_title}]
    end
    Application.neo.batch(*batch)
  end

  def create_relationships(page_node, link_nodes)
    batch = link_nodes.map do |response|
      [:create_relationship, 'links_to',  page_node['self'], response['body']['self']]
    end
    Application.neo.batch(*batch)
  end

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
end

class WikiLink
  def initialize(link)
    @link = link
  end

  def title
    canonicalize unsection unalias unwrap @link
  end

  def valid?
    namespace == "Main" && title != ''
  end

  private

  def namespace
    if @link.include? ":"
      @link.split(":").first
    else
      "Main"
    end
  end

  def unwrap(link)
    link[2..-3]
  end

  def unalias(link)
    link.split('|').first
  end

  def unsection(link)
    link.split('#').first
  end

  def canonicalize(link)
    link = link.gsub(/_+/, ' ')
    link = link.lstrip.rstrip
    link = link.slice(0,1).upcase + link.slice(1..-1) if link.length > 0
    link
  end
end

class Application
  attr_reader :dump_file

  class << self
    attr_reader :neo
  end

  @neo = Neography::Rest.new

  def initialize(dump_file)
    @dump_file = dump_file
  end

  def run
    dump.each do |node|
      page = Page.new node
      page.save
    end
  end

  private :dump_file

  def dump
    WikiDump.new xml
  end

  def xml
    File.new(dump_file)
  end
end


# Oops, my python is showing
if __FILE__ == $0
  Application.new(ARGV[0] || STDIN.fileno).run
end
