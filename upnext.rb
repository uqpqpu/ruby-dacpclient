require './lib/dacpclient'
require 'socket'

client = DACPClient.new "Ruby (#{Socket.gethostname})", 'localhost', 3689
client.login [1,2,3,4] #use this pin to pair in iTunes
databases = client.databases
db = databases.mlcl[0].miid
puts "Database: #{db}"
containers = client.playlists db
library = containers.mlcl[0].miid
puts "Library Playlist: #{library}"

search = 'Crossroads' #search term, only supports song name right now

results = client.search db, library, search
songs = []
results.mlcl.each { |x| songs.push({'name' => x.minm, 'artist' => x.asar, 'album' => x.asal, 'id' => x.miid}) }
puts songs

client.queue songs[0]['id'] #adds the first result to 'Up Next' in iTunes