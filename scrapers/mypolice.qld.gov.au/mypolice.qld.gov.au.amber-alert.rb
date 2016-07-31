#!/usr/bin/env ruby

require 'rubygems'
require 'open-uri'
require 'rss'
require 'awesome_print'
require 'json'
require 'csv'
require 'chronic'

# mashup of: https://stackoverflow.com/questions/4868969/implementing-a-simple-trie-for-efficient-levenshtein-distance-calculation-java
# and https://stackoverflow.com/questions/20012873/fast-fuzzy-approximate-search-in-dictionary-of-strings-in-ruby
# and http://stevehanov.ca/blog/index.php?id=114
# to create a suffix trie of all the suburbs and then use the suffix trie to lookup fuzzy matches
class Trie
  class Result
    attr_accessor :word
    attr_accessor :distance

    def initialize(word, distance)
      @word = word
      @distance = distance
    end

    def score
      self.word.size - self.distance
    end
  end

  class Node
    attr_accessor :word
    attr_accessor :children
    attr_accessor :max_length
    attr_accessor :depth

    def initialize
      @word = nil
      @children = {}
      @max_length = 0
    end

    def put(str)
      node = self
      length = str.size
      str.chars.each_with_index do |c, i|
        node = (node.children[c] ||= Node.new)
        node.max_length = length if node.max_length < length
        node.depth = i
      end
      node.word = str
    end

    def keys
      @children.keys
    end

    def [](key)
      @children[key]
    end
  end

  def initialize
    @root = Node.new
  end

  def put(str)
    @root.put str
  end

  def get(str)
    # tolerate 10% errror
    max_cost = (str.size/10.0).ceil
    length = str.size
    row = (0..length).to_a
    results = []
    @root.keys.each do |c|
      _search @root[c], c, str.downcase, length, row, results, max_cost
    end
    results
  end

  def _search(node, c, str, length, row, results, max_cost)
    new_row = [row[0] + 1]
    (1..length).each do |column|
      insert_cost = new_row[column - 1] + 1
      delete_cost = row[column] + 1
      replace_cost = ((str[column - 1] != c) ? (row[column - 1] + 1) : (row[column - 1]))
      new_row << [insert_cost, delete_cost, replace_cost].min
    end
    results << Result.new(node.word, new_row[-1]) if not node.word.nil? and new_row[-1] <= max_cost
    # if we are at the end of the input string and we are past the point at which
    # the additional characters in the index would exceed the max_cost we short circuit
    return if node.depth >= length and new_row[-1] + (node.depth - length) > max_cost
    node.keys.each do |c|
      _search node[c], c, str, length, new_row, results, max_cost
    end
  end
end

# read in the suburb database, partition by number of words and create an index
# for each partition
suburbs = open('suburbs.csv').readlines.map { |l| l.downcase.strip }
suburb_partitions = suburbs.group_by { |suburb| suburb.split.size }
suburb_indexes = suburb_partitions.each_with_object({}) do |(size, partition), h|
  index = Trie.new
  partition.each { |suburb| index.put suburb }
  h[size] = index
end
outcomes = {
  'located' => [
    'located',
    'found',
    'final'
  ]
}
outcome_indexes = outcomes.each_with_object({}) do |(outcome, synonyms), h|
  index = Trie.new
  synonyms.each { |synonym| index.put synonym }
  h[outcome] = index
end

CSV($stdout) do |csv|
  csv << ['title', 'suburb', 'published_at', 'categories', 'outcome', 'text']
  open('rss.xml') do |rss|
    feed = RSS::Parser.parse(rss)
    feed.items.each do |item|
      words = item.title.downcase.gsub(/[^\w ]/, '').split
      suburb_results = []
      suburb_indexes.keys.sort.each do |k|
        words.each_cons(k).map { |ws| ws.join ' ' }.each do |query|
          result = suburb_indexes[k].get query
          best = result.max_by { |p| p.score }
          suburb_results << best if best
        end
      end
      suburb = suburb_results.max_by { |result| result.score }.word

      # TODO: work out how to guess the outcome of a report based on keywords without
      # going all the way and doing machine learning. just add up the scores per outcome
      # and default to ongoing if we can't be confident it is a located. what are the
      # outcomes? located and on-going?
      best_outcome = Result.new('Unknown', Integer::MAX)
      outcome_indexes.each do |k, v|
        words.each do |query|
          result = outcome_indexes[k].get query
          best_outcome = result if result.score > best_outcome.score
        end
      end

      categories = item.categories.map { |c| c.content }.to_json
      outcome = 'Unknown'
      csv << [item.title, suburb, item.pubDate, categories, outcome, item.description ]
    end
  end
end
