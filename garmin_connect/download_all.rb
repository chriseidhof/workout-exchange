#!/usr/bin/ruby

require 'rubygems'
require 'mechanize'
require 'date'
require 'json'

user = ARGV[0]
password = ARGV[1]
from_date = Date.today.to_datetime
if not ARGV[2].nil?
  from_date = DateTime.parse(ARGV[2])
end

agent = Mechanize.new { |agent|
  agent.user_agent_alias= 'Mac Safari'
  agent.redirect_ok = true
  agent.follow_meta_refresh = true
  agent.pluggable_parser['text/xml'] = Mechanize::Page
  agent.pluggable_parser['application/vnd.garmin.gpx+xml'] = Mechanize::Download
}

# first log in
page = agent.get('http://connect.garmin.com/en-US/signin')

# find and load script
script_src = page.search("script [src]").select{ |script| script['src'].include? "sso.garmin.com"  }.first['src']
script = agent.get(script_src)

# get the gauth host name
hostname_page = agent.get('http://connect.garmin.com/gauth/hostname')
hostname = JSON::parse(hostname_page.body)['host']

# Get the iframe with the login form
login_page = agent.get('https://sso.garmin.com/sso/login', {
  'service' => 'http://connect.garmin.com/post-auth/login',
  'webhost' => hostname,
  'source' => 'http://connect.garmin.com/en-US/signin',
  'redirectAfterAccountLoginUrl' => 'http://connect.garmin.com/post-auth/login',
  'redirectAfterAccountCreationUrl' => 'http://connect.garmin.com/post-auth/login',
  'gauthHost' => 'https://sso.garmin.com/sso',
  'locale' => 'en',
  'id' => 'gauth-widget',
  'cssUrl' => 'https://static.garmincdn.com/com.garmin.connect/ui/src-css/gauth-custom.css',
  'clientId' => 'GarminConnect',
  'rememberMeShown' => 'true',
  'rememberMeChecked' => 'false',
  'createAccountShown' => 'true',
  'openCreateAccount' => 'false',
  'usernameShown' => 'true',
  'displayNameShown' => 'false',
  'consumeServiceTicket' => 'false',
  'initialFocus' => 'true',
  'embedWidget' => 'false'
})

# fill out and submit form
form = login_page.form_with(:id => 'login-form')
form.field_with(:id => 'username').value = user
form.field_with(:id => 'password').value = password
form_result = form.click_button

# find the url that gets us back to connect.garmin.com
login_url = form_result.body.scan(/response_url\s*=\s*'(.*)';/).first.first

# and finally login to connect.garmin.com
page = agent.get(login_url)
  
# fetch the last 20 workouts
page = agent.get('http://connect.garmin.com/activities')

xml = Nokogiri::XML(page.body)
xml.remove_namespaces!

xml.xpath("//tr[starts-with(@id, 'activitiesForm:activitiesGrid:n:')]").each do |activity| 
  id =  activity.css('td:eq(3) a').first['href'][/\d*$/]
  type = activity.css('td:eq(4)').text
  date_str = activity.css('td:eq(6)').text
  date = DateTime.parse(date_str)
  extension = "tcx"
  filename = "#{date.strftime('%Y%m%d-%H%M')}_#{type}_garmin.#{extension}"
  if File.exist?(filename) 
      $stderr.puts "#{filename} already exists"
      next
  end

  url = "http://connect.garmin.com/proxy/activity-service-1.2/#{extension}/activity/#{id}?full=true"
  $stderr.puts "downloading #{url} to #{filename}"
  agent.get(url).save(filename)
end                                    
