#!/usr/bin/env ruby

require 'rubygems'
require 'chronic'
require 'csv'
require 'awesome_print'
require 'date'
require 'open-uri'
require 'json'

rows = []
columns = []
CSV(ARGF, :headers => true, :return_headers => false) do |csv|
  csv.each do |row|
    rows << row
  end
end

# debugging code to extract the full set of detail key names
#rows.each do |row|
#  columns = (JSON.parse(row.entries.last.last).keys | columns)
#end
#puts columns.sort

CSV($stdout) do |csv|
  csv << [
    'name',
    'profile_picture',
    'missing_date',
    'age_now',
    'alias',
    'build',
    'complexion',
    'distinguishing_features',
    'ethnicity',
    'eyes',
    'gender',
    'hair',
    'height',
    'jurisdiction',
    'last_seen',
    'reward_offered',
    'year_of_birth'
  ]
  rows.each do |row|
    details = JSON.parse(row.entries.last.last)
    csv << [
      row['name'],
      row['profile_picture'],
      row['missing_date'],
      details.fetch('age_now:', ''),
      details.fetch('alias:', ''),
      details.fetch('build:', ''),
      details.fetch('complexion:', ''),
      details.fetch('distinguishing_features:', ''),
      details.fetch('ethnicity:', ''),
      details.fetch('eyes:', ''),
      details.fetch('gender:', ''),
      details.fetch('hair:', ''),
      details.fetch('height:', ''),
      details.fetch('jurisdiction:', ''),
      details.fetch('last_seen:', ''),
      details.fetch('reward_offered:', ''),
      details.fetch('year_of_birth:', '')
  ]
  end
end
