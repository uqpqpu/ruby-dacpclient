require 'digest'
require 'net/http'
require './lib/pairingserver'
require './lib/dmapparser'
require './lib/dmapbuilder'
require 'uri'
require 'cgi'

class DACPClient
  
  def initialize name, host = 'localhost', port = 3689
    @client = Net::HTTP.new host, port
    @name = name
    @host = host
    @port = port
    @service = nil
    @session_id = nil
  end
  
  def pair pin = nil
    pairingserver = PairingServer.new @name, '0.0.0.0', 1024
    pairingserver.pin = pin if !pin.nil?
    pairingserver.start
  end
  
  def self.getGUID name 
     d = Digest::SHA2.hexdigest name
     d[0..15]
  end
  
  def serverinfo
    do_action 'server-info'
  end

  def is_paired
	begin
	  response = do_action :'login', {'pairing-guid' => '0x'+ DACPClient::getGUID(@name)}
	  @session_id = response[:mlid]
	rescue DACPForbiddenError=>e
	  return false
	else
	  return true
	end
  end
  
  def login pin = nil
    response = do_action :'login', {'pairing-guid' => '0x'+ DACPClient::getGUID(@name)}
    @session_id = response[:mlid]
  rescue DACPForbiddenError=>e
    #puts "#{e.result.message} error: Cannot login, starting pairing process"
	if pin == nil
		pin = 4.times.map{ Random.rand(10)}
	end
    pair pin 
    retry
  end
  
  def content_codes
    do_action 'content-codes', {}, true
  end
  
  def play
    do_action :'play'
  end
  
  def playpause
    do_action :'playpause'
  end
  
  def stop
    do_action :'stop'
  end
  
  def pause 
    do_action :'pause'
  end
  
  def status 
    do_action :'playstatusupdate', {'revision-number' => 1}
  end
  
  def next
    do_action :'nextitem'
  end
  
  def prev
    do_action :'previtem'
  end

  def queue id
	do_action :'playqueue-edit', {}, false, {'command' => 'add', 'query' => "\'dmap.itemid:#{id}\'"}
  end

  def databases
    do_action :'databases', {}, true
  end

  def playlists db
    do_action :"databases/#{db}/containers", {}, true
  end

  def search db, container, search
	words = search.split
	queries = []
	queries.push(words.map{|v| "\'dmap.itemname:*#{v}*\'"}.join('+'))
	#queries.push(words.map{|v| "\'daap.songartist:*#{v}*\'"}.join('+'))
	query = queries.map{|q| "(#{q})"}.join(',')
	#puts query
	do_action :"databases/#{db}/containers/#{container}/items", {'type' => 'music', 'sort' => 'album'}, true, {'meta' => 'dmap.itemid,dmap.itemname,daap.songartist,daap.songalbum', 'query' => "(#{query})"}
  end
  
  def get_volume
    response = do_action :'getproperty', {'properties' => 'dmcp.volume'}
    response[:cmvo]
  end
  
  def set_volume volume
    do_action :'setproperty', {'dmcp.volume' => volume}
  end
  
  def ctrl_int
    do_action 'ctrl-int',{},false
  end
  
  def logout
    do_action :'logout', {}, false
  end
  
  private
  
  def do_action action, params = {}, cleanurl = false , moreparams = {}
    action = '/'+action.to_s
    if !@session_id.nil?
      params['session-id'] = @session_id
      action = '/ctrl-int/1'+action unless cleanurl
    end
    params = params.map{|k,v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join '&'
	if !moreparams.empty?
		moreparams = moreparams.map{|k,v| "#{k}=#{v}"}.join '&'
		params = "#{params}&#{moreparams}"
	end
	
    uri = URI::HTTP.build({:host => @host, :port => @port, :path => action, :query => params})
    req = Net::HTTP::Get.new(uri.request_uri)
	#puts uri.request_uri
    req.add_field 'Viewer-Only-Client', '1'
    res = Net::HTTP.new(uri.host, uri.port).start {|http| http.request(req) }
    if res.kind_of? Net::HTTPServiceUnavailable or res.kind_of? Net::HTTPForbidden
      raise DACPForbiddenError.new res
    elsif !res.kind_of? Net::HTTPSuccess 
      p res
      return nil
    end
    DMAPParser.parse res.body
  end
end
class DACPForbiddenError < StandardError
  attr :result
  def initialize res
    @result = res
  end
end
