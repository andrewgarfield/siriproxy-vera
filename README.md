SiriProxy-Vera
==========

About
-------
I have a VeraLite, and I have an iPhone (with Siri).  Though there are great apps for the iPhone that allow me to control Vera, they can be quite annoying to have to access just to run a simple scene or control a light.  

Just by chance I happened upon the awesome SiriProxy program that would allow me to control Vera through Siri.  I was hoping that somebody else would write a nice plugin like this so that I could just install and run it, but after the better part of a year (since I learned about SiriProxy), I couldn't find anything. So I decided to write one myself.

This plugin, at least in it's current iteration, allows for control of three things and three things only:

	- Scenes
	- Binary Lights
	- Dimmable Lights

The plugin automatically fetches each of the devices and scenes of these kinds and makes them available.

No, the plugin does not yet control thermostats, but I (or another contributor) might add this down the road.


Usage
-------

Once the plugin is installed and the server is running you can ask it to do several things.  Here's the list of what it is listening for.

    **To run a scene**
    You: "Set scene <scene name>"
    Siri: "Running scene <scene name>"
    
    **To change the brightness of a dimmer**
    You: "Change <dimmable light name>"
    Siri: "To what should I change <dimmable light night> to?"
    You: "50"
    Siri: "Turning <dimmable light name> to 50 percent."
    
    **To turn on/off a light switch**
    You: "Turn on the <light name>"
    Siri: "Turning <light name> on."
    
    **Asking how many scenes Siri knows about (for testing purposes)**
    You: "How many scenes do you know?"
    Siri: "I know about <number of scenes> scenes.
    
Installation
-------------

This installation assumes that you already have SiriProxy installed.  If you do not, please visit the [SiriProxy](https://github.com/plamoni/SiriProxy/) page and go through the nicely written guides there to set things up.

To install SiriProxy-Vera into your SiriProxy server, please perform the following steps.

1. Add the following information to your installation's config.yml file:

      - name: 'Vera'
        git: 'git://github.com/andrewgarfield/siriproxy-vera.git'
        vera_ip: 'vera' # enter the ip or hostname for your vera
        vera_port: '3480'
      
2. Change the "vera_ip" option within the stuff you just pasted into config.yml to the IP address or hostname of your vera unit.

    `vera_ip: '192.168.1.56'
    
3. Update your SiriProxy installation
4. 
    `rvmsudo siriproxy update`

4. Start the SiriProxy server

    `rvmsudo siriproxy server -u nobody`

If the plugin is installed correctly you will see a message like this as the server starts up:

  "Vera plugin running. Detected 20 scenes, 4 dimmable lights, and 7 binary lights."
    
FAQ
----------

**Do you plan on adding thermostat control to this plugin?**

Yes, eventually.  It really depends on how much I really feel like I'm missing this particular feature in when it'll be done.  Usually my thermostat is controlled by certain scenes triggered by my alarm system, so I don't generally need the ability to change my thermostat manually. Feel free to add it yourself and contribute it back though!

**When I say "fifty" to Siri to set my dimmable light, it recognizes it as "fifty" and not "50".  Then the action doesn't run.  What gives?**

This is a limitation of Siri, and SiriProxy in general in how it parses those words.  Instead of saying "fifty" trying saying each number (5-0) in rapid succession.  Siri should then parse it in numbers.

I do hope to eventually add in gems that can make the english to number conversion for us, but I haven't had the time to explore this yet.

**Why is setting a dimmable light a two step process?**

You can look back at my commit history to see all of the permutations of english words I put together in order to try to make this work in a single sentence.  However, thanks to the regex I used, and Siri's language parsing alghorithms I couldn't find a good way to say it in English that worked regularly.

The biggest issue is that in English we usually tell someone to set something "to 50".  Since we must spell out "5-0" individually, Siri takes this as we are trying to tell it to set something "250", making 'to" into the number '2".

Changing it the way I did really helped the reliability, at least with how I speak.

**Siri is interpreting things that I say in a weird way.  Can we fix this?**

We might be able to.  For example, when I talk to Siri and tell it to "Set Scene Home Mode", it often interprets the word "scene" also as "seen" and "seem".  This is annoying.  However, I was able to set the listener to accept all three of those words.  Now "Set seem Home Mode" works the same as "Set seen Home Mode".  However, this may not be doable in all cases.

**Can I just tell Siri to turn a dimmable light on/off instead of having to set its brightness to 100?"**

Yes! I wrote this specifically into the code for these functions.  Since dimmable lights also can be told to simply turn off and on, I made sure this plugin would treat it the same as regular binary lights in this context.

**I added/deleted/changed a scene or device on my Vera.  How do I get the plugin to pick up the changes?**

I plan to shortly add a refresh option so that you can just ask Siri to reload it.  But for now, simply stop and restart the SiriProxy server and it will fetch the updated information.

**I cannot set certain scenes because I cannot pronounce them in a way that Siri will understand.  What can I do?**

I had this on a few of my scenes as well.  I had a few scenes that my wife ran in stages as she put my daughter to bed.  They were called something like "Stage II - Mia Sleep".  I wouldn't even know how to speak that in a way the plugin would understand.

The solution? Make your scene names less complicated.  I suggest using no more than 2-3 word names.  While you're at it, you should probably rename all your scenes into a more speech-friendly way.  SiriProxy and this plugin can not guess what you meant to say, it has to be an exact match to the name of a scene or device in order for it to make the connections. 


Acknowledgements
-----------------
[kreynold's ruby-mios gem](https://github.com/kreynolds/ruby-mios) - This gem is NOT used in this plugin, nor did I directly lift any code from it.  I did however take a look at it to see how the developer made some of the calls to Vera and parsed how it came out.  Doing so saved me a decent amount of time.  So credit where credit is due.

I want to thank my daughter Mia who slept so soundly as I was coding this up.


Licenses
----------
This software is licensed under the MIT license.

Copyright (C) 2013 Andrew Garfield

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
