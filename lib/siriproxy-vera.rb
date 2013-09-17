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
    @dimmable_lights = parse_dimmable_lights(data)
    @binary_lights = parse_binary_lights(data)
    @alarm = parse_alarm(data)
    puts "Vera plugin running.  Detected #{@scenes.size} scenes, #{@dimmable_lights.size} dimmable lights, and #{@binary_lights.size-@dimmable_lights.size} binary lights."
  end
  
  def reload_from_vera
    old_binary_lights = @binary_lights
    old_dimmable_lights = @dimmable_lights
    old_scenes = @scenes
    @binary_lights, @dimmable_lights, @scenes = {}
    data = MultiJson.load(@client.get("#{@base_uri}/data_request", {:id => "user_data", :output_format => :json}).content)
    @scenes = parse_scenes(data)
    @dimmable_lights = parse_dimmable_lights(data)
    @binary_lights = parse_binary_lights(data)
    response = "Detected: "
    response += (old_scenes == @scenes) ? "No Scene Changes. " : "Changes to Scenes. "
    response += (old_binary_lights == @binary_lights) ? "No Binary Light Changes. " : "Changes to Binary Lights. "
    response += (old_dimmable_lights == @dimmable_lights) ? "No Dimmable Light Changes. " : "Changes to Dimmable Lights" 
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
    lights = lights.merge(@dimmable_lights.each{|key,value| value.merge!({'serviceId' => 'urn:upnp-org:serviceId:SwitchPower1'})}) unless @dimmable_lights.zero?
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
  
  def parse_alarm(data)
    for device in data['devices']
      if device['category_num'] == 23
        for state in device["states"]
          return {'DeviceNum' => device['id'], 'serviceId' => state["service"]} if state["variable"] == "ArmMode"
        end
      end
    end
  end
  
  # Created a simplified function to pull variable information from vera.  
  def get_variable(device, variable)
    @client.get("#{@base_uri}/data_request", {:id => "variableget", "Variable" => variable}.merge(device)).content
  end
  
  # Created a simplified function to perform actions on a vera system.
  def perform_action(device, action, variable, set_to)
    @client.get("#{@base_uri}/data_request", {:id => "action", :action => action, variable.to_sym => set_to}.merge(device)).content
  end
  
  # Higher level call to set up the action required to turn on/off the light.  Sets up action for both dimmable lights
  # or for binary lights since both can be set to on or off in a binary fashion.
  def turn(light, on_or_off)
    target = "1" if on_or_off.downcase == "on" 
    target = "0" if on_or_off.downcase == "off"
    perform_action(light, "SetTarget", "newTargetValue", target) 
  end 
  
  # a good listen function just for testing siriproxy-vera.
  listen_for /how many scenes do you know/i do
    say "I know about #{@scenes.size} scenes."

    request_completed
  end

  # Reloads the device and scene information from vera through a listen command.
  listen_for /reload device information/i do
    response = reload_from_vera
    say response, spoken: "Okay, I have reloaded the configuration from Vera."

    request_completed
  end
  
  # Turns on or off a binary or dimmable light.
  listen_for /turn ([a-z]*) (?:the )?([\d\w\s]*)/i do |on_or_off, input|
    lights = @binary_lights.merge(@dimmable_lights) #merge the binary and dimmabe light hashes.
    
    if lights.has_key?(input.downcase) # Search the keys in the lights hash for a match to the input.
      result = turn(lights[input.downcase], on_or_off) # Perform the action to turn on/off the lights.
      say "Turning #{input.downcase} #{on_or_off}." if result
      say "Error turning #{input.downcase} #{on_or_off}." if not result
    else
      say "Couldn't find a device by the name #{input}."
    end

    request_completed
  end
  
  # Turns your alarm partition to away (or more technically "Armed") mode.
  listen_for /(?:I|We) (?:am|are) leaving/ do
    if @alarm # Ensures that siriproxy-vera found an alarm panel from your system.
      arm_mode = get_variable(@alarm, "ArmMode")
      detailed_arm_mode = get_variable(@alarm, "DetailedArmMode")
      if (arm_mode == "Disarmed") and (detailed_arm_mode != "NotReady")
        request = perform_action(@alarm, "RequestArmMode", "State", "Armed") # Runs call to arm the system.
        say "Be Safe!  See you soon!", :spoken => "Okay, I'll prepare the house for you." if request
        say "Sorry but something went wrong." if not request
      else
        say "For security reasons, I am programmed to never disarm your system.", :spoken => "Sorry, the alarm is either not ready or already armed."
      end
    else
      say "Sorry, I cannot find an alarm among your devices."
    end
    
    request_completed
  end
  
  # Turns your alarm partition to Stay mode.
  listen_for /(?:I|We) (?:am|are) staying in/ do
    if @alarm # Ensures that siriproxy-vera found an alarm panel from your system.
      arm_mode = get_variable(@alarm, "ArmMode")
      detailed_arm_mode = get_variable(@alarm, "DetailedArmMode")
      if (arm_mode == "Disarmed") and (detailed_arm_mode != "NotReady")
        request = perform_action(@alarm, "RequestArmMode", "State", "Stay")  # Runs call to arm the system.
        say "Okay, I will arm the house for you." if request
        say "Sorry but something went wrong." if not request
      else
        say "For security reasons, I am programmed to never disarm your system.", :spoken => "Sorry, the alarm is either not ready or already armed."
      end
    else
      say "Sorry, I cannot find an alarm among your devices."
    end
    
    request_completed
  end
  
  # Turns your alarm partition to Stay mode.
  listen_for /(?:I|We) (?:am|are) going to sleep/ do
    if @alarm # Ensures that siriproxy-vera found an alarm panel from your system.
      arm_mode = get_variable(@alarm, "ArmMode")
      detailed_arm_mode = get_variable(@alarm, "DetailedArmMode")
      if (arm_mode == "Disarmed") and (detailed_arm_mode != "NotReady")
        request = perform_action(@alarm, "RequestArmMode", "State", "Night")  # Runs call to arm the system.
        say "Okay, I will prepare the house for you.  Goodnight and sweet dreams!" if request
        say "Sorry but something went wrong." if not request
      else
        say "For security reasons, I am programmed to never disarm your system.", :spoken => "Sorry, the alarm is either not ready or already armed."
      end
    else
      say "Sorry, I cannot find an alarm among your devices."
    end
    
    request_completed
  end
  
  # Listen command to change the light level of a dimmable light
  listen_for /change (?:the )?(?:brightness of the|brightness of)?([\d\w\s]*)/i do |input|
    if @dimmable_lights.has_key?(input.downcase) # Search the keys in the @dimmable_lights hash for a match to the input.
      number = ask "To what should I change #{input.downcase} to?"
      if (number =~ /([0-9,]*[0-9])/i) and ((number.to_i <= 100) and (number.to_i >= 0)) # Ask for additional input the dim level.
        result = perform_action(@dimmable_lights[input.downcase], "SetLoadLevelTarget", "newLoadlevelTarget", number)
        say "Turning #{input.downcase} to #{number} percent." if result
        say "Error turning #{input.downcase} to #{number} percent." if not result
      else
        say "Sorry, but the number #{number} is not within specification."
      end
    else
      say "Couldn't find a device by the name #{input}."
    end

    request_completed
  end
  
  # listen command to run a particular scene.
  listen_for /set (?:scene|seen|seem)?(?:to )?([\d\w\s]*)/i do |input|
    if @scenes.has_key?(input.downcase) # Search the keys in the @scenes hash for a match to the input.
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
end
