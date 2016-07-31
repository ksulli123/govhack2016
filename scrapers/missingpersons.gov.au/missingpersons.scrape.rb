#!/usr/bin/env ruby

require 'rubygems'
require 'chronic'
require 'hpricot'
require 'csv'
require 'awesome_print'
require 'date'
require 'open-uri'
require 'thread'
require 'json'

BASE = 'https://www.missingpersons.gov.au'
MAX_THREADS = 10

CSV($stdout) do |csv|
  csv << ['name', 'profile_picture', 'missing_date', 'details']

  # create a queue so we can download pages while we are parsing them
  queue = SizedQueue.new MAX_THREADS
  # use a Mutex to protect the csv so only one thread can add a row at a time
  mutex = Mutex.new
  threads = (1..MAX_THREADS).map do |i|
    Thread.new(queue, mutex) do |q, m|
      until (q == (page = q.deq))
        doc = Hpricot(open(page).read)
        profile_picture = (doc/'//div[@class="profileImage"]/img').first['src']
        content = (doc/'//div[@class=content]')
        name = (content/'//h1#page-title').text.gsub(/[\s]+/, ' ').strip
        details = Hash.new
        (content/'//ul[@class="profileDetails"]/li').each do |li|
          next if li['class'].eql? 'missingSince'
          field = (li/'//span').first.inner_html.strip.tr('[A-Z ]', '[a-z_]')
          data = (li/'//span').last.inner_html.strip
          details[field] = data
        end
        missing_date = Chronic.parse (content/'ul[@class="profileDetails"]/li[@class="missingSince"]//span[@class="date-display-single"]').first['content']
        m.synchronize {
          csv << [name, profile_picture, missing_date, details.to_json]
        }
      end
    end
  end

  # open the first page and add all of the missing people profile pages to the queue
  doc = Hpricot(open('https://www.missingpersons.gov.au/view-all-profiles').read)
  $stderr.puts 'https://www.missingpersons.gov.au/view-all-profiles'
  (doc/'//div[@class="view-content"]//a').each do |a|
    $stderr.puts BASE + a['href']
    queue << BASE + a['href']
  end
  # find the link to the next missing people index page
  next_link = (doc/'//div[@class="pager"]//li[@class="pager-next"]/a')
  while not next_link.empty?
    $stderr.puts BASE + next_link.first['href']
    # got to the next index page and add all of the missing people profile pages to the queue
    doc = Hpricot(open(BASE + next_link.first['href']).read)
    (doc/'//div[@class="view-content"]//a').each do |a|
      $stderr.puts BASE + a['href']
      queue << BASE + a['href']
    end
    # find the link to the next missing people index page
    next_link = (doc/'//div[@class="pager"]//li[@class="pager-next"]/a')
  end

  # add the terminals (the queue itself) to the queue, once for each thread
  threads.size.times { queue << queue }

  # wait for the threads to finish
  threads.each { |thread| thread.join }
end
