
<h1 align="center">
  AdaptiveRea
</h1>

<h4 align="center">A set of ReaScripts for integrating REAPER with Unity to create adaptive music systems.</h4>

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#how-to-use">How to use</a> •
  <a href="#credits">Credits</a> •
  <a href="#license">License</a>
</p>

## Key Features

* Horizontal composition with transition clips
* Vertical composition with volume and FX automatization
* MIDI scatterer with parameterized spawnrate
* OSC communication with Unity to control parameters

## Installation
### Manual
1. Clone repository into Reaper script folder
2. Go to *Actions > Show Action List*
3. Click *New/Load*
4. Load all 4 scripts

### Reapack
*(Coming soon)*

## How to use
### Unity OSC
- Install [Unity OSC](https://t-o-f.info/UnityOSC/)
- Open AdaptiveHost script and set port *(default 9000)*
- Create and name the parameters you want to make use of in the scripts *(check each scripts HowToUse section)*
- Create OSCTransmitter
```c#
// Creating a transmitter
var transmitter = gameObject.AddComponent<OSCTransmitter>();

// Set remote host address
transmitter.RemoteHost = "127.0.0.1";    

// Set port number also set in Adaptivehost
transmitter.RemotePort = 9000;         
```
- Send Play Message
```c#
// Create message
var message = new OSCMessage("play");

// Send message
transmitter.Send(message);      
```
- Send Stop Message
 ```c#
// Create message
var message = new OSCMessage("stop");

// Send message
transmitter.Send(message);        
```
- Send Parameter value
```c#
  // To send parameter value first set message adress to "param"
  var message = new OSCMessage("param");

  //  First set name of the parameter as a string
  message.AddValue(OSCValue.String("MyParam"));

  // Add parameter value (accepts only float value with range 0-1)
  message.AddValue(OSCValue.Float(0.78));

  // Send message
  transmitter.Send(message);
```
### Layers
### GoTo
### Scatterer

## Credits

## License

MIT
