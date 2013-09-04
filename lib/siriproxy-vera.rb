require 'cora'
require 'siri_objects'
require 'pp'
require 'httpclient'
require 'multi_json'

class SiriProxy::Plugin::Vera < SiriProxy::Plugin
  attr_accessor :vera_ip
  attr_accessor :vera_port
  
  def initialize(config)
    #if you have custom configuration options, process them here!
    @base_uri = "http://#{config["vera_ip"]}:#{config['vera_port']}"
    @client = HTTPClient.new
    data = MultiJson.load(@client.get("#{@base_uri}/data_request", {:id => "user_data", :output_format => :json}).content)
    @scenes = parse_scenes(data)
    @binary_lights = parse_binary_lights(data)
    @dimmable_lights = parse_dimmable_lights(data)
    puts "Vera plugin running.  Detected #{@scenes.size} scenes, #{@dimmable_lights.size} dimmable lights, and #{@binary_lights.size} binary lights."
  end
  
  def reload_from_vera
    old_binary_lights = @binary_lights
    old_dimmable_lights = @dimmable_lights
    old_scenes = @scenes
    @binary_lights, @dimmable_lights, @scenes = {}
    data = MultiJson.load(@client.get("#{@base_uri}/data_request", {:id => "user_data", :output_format => :json}).content)
    @scenes = parse_scenes(data)
    @binary_lights = parse_binary_lights(data)
    @dimmable_lights = parse_dimmable_lights(data)
    response = "Detected: "
    response += (old_scenes == @scenes) ? "Changes to Scenes." : "No Scene Changes"
    response += (old_binary_lights == @binary_lights) ? "Changes to Binary Lights." : "No Binary Light Changes."
    response += (old_dimmable_lights == @dimmable_lights) ? "Changes to Dimmable Lights" : "No Dimmable Light Changes"
    puts response
    return response
  end
  
  # This function parses scene information from the vera config file, and creates a hash with each scene name and 
  # it's scene Id. Each scene name is converted to be all lowercase and have any punctuations and numbers stripped 
  # out. So a scene named "Alarm On!" becomes "alarm on". This is because the plugin performs a direct match 
  # between the english words it receives from Siri, and the object name.  We have to sanitize the device names to
  # fit the expected output from siri.
  def parse_scenes(data)
    scenes = Hash.new
    data['scenes'].each {|scene| scenes[scene['name'].downcase.gsub(/[^a-z\s]/,"")] = scene['id'].to_s}
    return scenes
  end
  
  # This parses binary lights from the vera config file, and creates a hash with the device number, and service id 
  # for turning on and off the lights.  The device names are sanitized (as discussed above) to conform to expected
  # siri output.
  def parse_binary_lights(data)
    lights = Hash.new
    for device in data['devices']
      if device['device_type'] == "urn:schemas-upnp-org:device:BinaryLight:1"
        lights[device['name'].downcase.gsub(/[^a-z\s]/,"")] = {'DeviceNum' => device['id'], 'serviceId' => 'urn:upnp-org:serviceId:SwitchPower1'}
      end
    end
    return lights
  end
  
  # This parses dimmable lights from the vera config file, and creates a hash with the device number, and service id 
  # for controlling the brightness of the lights.  The device names are sanitized (as discussed above) to conform to
  # expected siri output
  def parse_dimmable_lights(data)
    lights = Hash.new
    for device in data['devices']
      if device['device_type'] == "urn:schemas-upnp-org:device:DimmableLight:1"
        lights[device['name'].downcase.gsub(/[^a-z\s]/,"")] = {'DeviceNum' => device['id'], 'serviceId' => 'urn:upnp-org:serviceId:Dimming1'}
      end
    end
    return lights
  end
  
  # Higher level call to set up the action required to turn on/off the light.  Sets up action for both dimmable lights
  # or for binary lights since both can be set to on or off in a binary fashion.
  def turn(light, on_or_off)
    if light['serviceId'] == "urn:upnp-org:serviceId:SwitchPower1"
      perform_action = {:action => "SetTarget"}
      perform_action['newTargetValue'] = "1" if on_or_off.downcase == "on" 
      perform_action['newTargetValue'] = "0" if on_or_off.downcase == "off"
      set_light(light, perform_action) 
    elsif light['serviceId'] == "urn:upnp-org:serviceId:Dimming1"
      turn_dimmable(light, 100) if on_or_off.downcase == "on"
      turn_dimmable(light, 0) if on_or_off.downcase == "off" 
    end

  end
  
  # Same as turn(light, on_or_off) only for dimmable lights
  def turn_dimmable(light, to_load_level)
    perform_action = {"action" => "SetLoadLevelTarget", "newLoadlevelTarget" => to_load_level}
    set_light(light, perform_action)
  end
  
  # Performs actual call to the vera box to perform the task
  def set_light(light, to_level)
    return @client.get("#{@base_uri}/data_request",
    {'id' => 'lu_action'}.merge(light).merge(to_level))
  end
  
  listen_for /how many scenes do you know/i do
    say "I know about #{@scenes.size} scenes."

    request_completed
  end

  listen_for /reload device information/i do
    response = reload_from_vera
    say response, spoken: "Okay, I have reloaded the configuration from Vera."

    request_completed
  end
  
  listen_for /turn ([a-z]*) the ([\d\w\s]*)/i do |on_or_off, input|
    lights = @binary_lights.merge(@dimmable_lights)
    
    #say "I undestood #{input}"
    if lights.has_key?(input.downcase)
      result = turn(lights[input.downcase], on_or_off)
      say "Turning #{input.downcase} #{on_or_off}." if result
      say "Error turning #{input.downcase} #{on_or_off}." if not result
    else
      say "Couldn't find a device by the name #{input}."
    end

    request_completed
  end
  
  # listen_for /set level ([0-9,]*[0-9]) on ([\d\w\s]*)/i do |number,input|
  listen_for /change ([\d\w\s]*)/i do |input|
    if @dimmable_lights.has_key?(input.downcase)
      number = ask "To what should I change #{input.downcase} to?"
      if (number =~ /([0-9,]*[0-9])/i) and ((number.to_i <= 100) and (number.to_i >= 0))
        result = turn_dimmable(@dimmable_lights[input.downcase], number)
        say "Turning #{input.downcase} to #{number} percent." if result
        say "Error turning #{input.downcase} to #{number} percent." if not result
      end
    else
      say "Couldn't find a device by the name #{input}."
    end

    request_completed
  end
  
  listen_for /set (scene|seen|seem) ([\d\w\s]*)/i do |spacer,input|
    #say "I undestood #{input}"
    if @scenes.has_key?(input.downcase)
      result = @client.get("#{@base_uri}/data_request",
      {:id => "lu_action", 
        :serviceId => "urn:micasaverde-com:serviceId:HomeAutomationGateway1", 
        :action => "RunScene", 
        :SceneNum => @scenes[input.downcase]})
        say "Running scene #{input.downcase}." if result
        say "Error running scene #{input.downcase}." if not result
    else
        say "Couldn't find a scene by the name #{input}."
    end

      request_completed
  end

  # #get the user's location and display it in the logs
#   #filters are still in their early stages. Their interface may be modified
#   filter "SetRequestOrigin", direction: :from_iphone do |object|
#     puts "[Info - User Location] lat: #{object["properties"]["latitude"]}, long: #{object["properties"]["longitude"]}"
# 
#     #Note about returns from filters:
#     # - Return false to stop the object from being forwarded
#     # - Return a Hash to substitute or update the object
#     # - Return nil (or anything not a Hash or false) to have the object forwarded (along with any
#     #    modifications made to it)
#   end
# 
#   listen_for /where am i/i do
#     say "Your location is: #{location.address}"
#   end
# 
#   listen_for /test siri proxy/i do
#     say "Siri Proxy is up and running!" #say something to the user!
# 
#     request_completed #always complete your request! Otherwise the phone will "spin" at the user!
#   end
# 
#   #Demonstrate that you can have Siri say one thing and write another"!
#   listen_for /you don't say/i do
#     say "Sometimes I don't write what I say", spoken: "Sometimes I don't say what I write"
#   end
# 
#   #demonstrate state change
#   listen_for /siri proxy test state/i do
#     set_state :some_state #set a state... this is useful when you want to change how you respond after certain conditions are met!
#     say "I set the state, try saying 'confirm state change'"
# 
#     request_completed #always complete your request! Otherwise the phone will "spin" at the user!
#   end
# 
#   listen_for /confirm state change/i, within_state: :some_state do #this only gets processed if you're within the :some_state state!
#     say "State change works fine!"
#     set_state nil #clear out the state!
# 
#     request_completed #always complete your request! Otherwise the phone will "spin" at the user!
#   end
# 
#   #demonstrate asking a question
#   listen_for /siri proxy test question/i do
#     response = ask "Is this thing working?" #ask the user for something
# 
#     if(response =~ /yes/i) #process their response
#       say "Great!"
#     else
#       say "You could have just said 'yes'!"
#     end
# 
#     request_completed #always complete your request! Otherwise the phone will "spin" at the user!
#   end
# 
#   #demonstrate capturing data from the user (e.x. "Siri proxy number 15")
#   listen_for /siri proxy number ([0-9,]*[0-9])/i do |number|
#     say "Detected number: #{number}"
# 
#     request_completed #always complete your request! Otherwise the phone will "spin" at the user!
#   end
# 
#   #demonstrate injection of more complex objects without shortcut methods.
#   listen_for /test map/i do
#     add_views = SiriAddViews.new
#     add_views.make_root(last_ref_id)
#     map_snippet = SiriMapItemSnippet.new
#     map_snippet.items << SiriMapItem.new
#     utterance = SiriAssistantUtteranceView.new("Testing map injection!")
#     add_views.views << utterance
#     add_views.views << map_snippet
# 
#     #you can also do "send_object object, target: :guzzoni" in order to send an object to guzzoni
#     send_object add_views #send_object takes a hash or a SiriObject object
# 
#     request_completed #always complete your request! Otherwise the phone will "spin" at the user!
#   end
end
