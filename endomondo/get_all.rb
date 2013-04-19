#!/usr/bin/ruby

require 'rubygems'
require 'mechanize'
require 'date'
require 'zip'

email = ARGV[0]
password = ARGV[1]
format = ARGV[2]
from_date = Date.today
if not ARGV[3].nil?
  from_date = Date.parse(ARGV[3])
end

agent = Mechanize.new { |agent|
  agent.user_agent_alias= 'Mac Safari'
  agent.pluggable_parser['text/xml'] = Mechanize::Page
}

# first log in
page = agent.get('https://www.endomondo.com/access')
form = page.form_with(:name => 'signInForm')

form.field_with(:name => 'email').value = email
form.field_with(:name => 'password').value = password
form.click_button

# fetch the workout page
page = agent.get('http://www.endomondo.com/workouts')
              
# get current year
year = page.search('//span[@class="year"]')[0].text.to_i              
# get current month
month = page.search('//li[@class="current"]/a/@onclick').first.value.match(/months:(\d+):month/)[1].to_i+1
# get current day
day = page.search('//div[div/span[@class="selected"]]/span')[0].text.to_i

target_date = Date.new(year, month, day)
# to store all workouts
workouts = Array.new
                                         
while target_date >= from_date do
  # add all workouts from this day, if any
  $stderr.puts "checking #{target_date}"
  page.search("//td[not(contains(@class, 'not-in-month'))]/div[span[@class='cday'][.=#{target_date.day}]]/div/span/a/@href").each do |link|
    workouts.push(link.value)
    $stderr.puts "found #{link.value}"
  end
  
  if (target_date.day == 1)
    $stderr.puts "changing month"
    # got to previous month 
    # find current month
    # todo to to previous year if needed (month = 1)
    prev_month_link = page.search('//div[@class="month-nav"]//li[@class="current"]').first.previous_sibling.search('a/@href').first.value
    page = agent.get(prev_month_link)
        
    # create link for previous month
    # click linke
  
  end
  target_date -= 1;  
end 

temp_zip = Tempfile.new(rand(32**8).to_s(32))
Zip::ZipOutputStream.open(temp_zip.path) { |zip|
  workouts.each { |href|
    $stderr.puts "fetching #{href}"
    page = agent.get(href)
    link = page.link_with(:text => 'Export').attributes['onclick'].match(/wicketAjaxGet\('(.*wicket.+?)'/)[1]
    # $stderr.puts "found #{link}"
    href = href + "/" + link
    # $stderr.puts "joined link #{href}"
    page = agent.get(href)
    link = page.link_with(:text => /#{format}/).href
    page = agent.get("http://www.endomondo.com/workouts/#{link}")
    # page.save_as("#{href.slice(/\d+/)}.#{format}")
    zip.put_next_entry("#{href.slice(/\d+/)}.#{format}")
    zip.print page.body
  }
}

$stdout.puts temp_zip.read

temp_zip.close
temp_zip.delete
