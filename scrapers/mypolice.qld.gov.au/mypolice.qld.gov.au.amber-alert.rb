#!/usr/bin/env ruby

require 'rubygems'
require 'open-uri'
require 'rss'
require 'awesome_print'
require 'json'
require 'csv'
require 'chronic'
require 'sanitize'

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

class String
  def sanitize
    Sanitize.clean self
  end
end

def max_total_score_from(words, indexes)
  # initially attempt to work out the status based on the title
  max_scores = {}
  indexes.each do |id, index|
    scores = words.map { |query| index.get query }
    total_score = scores.reduce(0) do |accumulator, results|
      accumulator + results.reduce(0) { |acc, result| acc + result.score } if not results.nil?
    end
    max_scores[id] = total_score
  end
  max_scores.max_by { |k, v| v }
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
    'final',
    'completed',
    'recovered',
    'cancelled'
  ],
  'ongoing' => [
    'ongoing',
    'continuing',
    'in progress',
    'progressing',
    'developing'
  ]
}
outcome_indexes = outcomes.each_with_object({}) do |(outcome, synonyms), h|
  index = Trie.new
  synonyms.each { |synonym| index.put synonym }
  h[outcome] = index
end

CSV($stdout) do |csv|
  csv << ['title', 'suburb', 'published_at', 'outcome', 'categories', 'text']
  open('rss.xml') do |rss|
    feed = RSS::Parser.parse(rss)
    # calculate the term frequencies, the document frequencies
    terms = Hash.new
    documents = Hash.new
    document_dates = Hash.new
    number_of_documents = 0
    feed.items.each_with_index do |item, index|
      item.description.sanitize.downcase.gsub(/[^\w ]/, '').split.each do |term|
        terms[term] ||= Hash.new 0
        terms[term][index] += 1
        documents[term] ||= Set.new
        documents[term] << index
      end
      number_of_documents = index
      document_dates[index] = item.pubDate
    end
    # extract the features as the terms that have a positive tfidf for at least one document
    features = Set.new
    terms.each do |term, docs|
      docs.each do |doc, count|
        tfidf = count * Math.log(number_of_documents/documents[term].size)
        features << term if tfidf > 0
      end
    end
    # for each document create a feature vector that we can cluster using
    vectors = Hash.new
    document_dates.each do |document, date|
      vectors[document] = []
      vectors[document] << date
      features.each do |feature|
        vectors[document] << terms[feature][document] * Math.log(number_of_documents/documents[feature].size)
      end
    end
    ap vectors
    exit
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
      # attempt to determine the outcome from the title
      outcome = max_total_score_from words, outcome_indexes
      if not (outcome and outcome.last > 0)
        # if we couldn't, then try the article text
        outcome = max_total_score_from item.description.sanitize.downcase.gsub(/[^\w ]/, '').split, outcome_indexes
      end
      outcome = nil if outcome.last.eql? 0
      categories = item.categories.map { |c| c.content }.to_json
      csv << [item.title, suburb, item.pubDate, (outcome ? outcome.first : 'unknown'), categories, item.description]
    end
  end
end
