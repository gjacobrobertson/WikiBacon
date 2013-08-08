require 'httpclient'

@client = HTTPClient.new

payload = ARGV.shift || STDIN.fileno

File.open payload do |f|
  header = {"Content-Type"=>"application/json",  "User-Agent"=>"Neography/1.0.10"}
  body = f.read
  host = 'http://localhost:7474/db/data/batch'
  response = @client.post host, body, header
  puts response.body
end
