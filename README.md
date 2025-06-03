
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

## Video demo



https://github.com/user-attachments/assets/1ff2dbd0-810c-4d32-85b2-80835ceba29d



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
- Change BPM value
```c#
// Create message
var message = new OSCMessage("BPM");

//  Add new BPM value
  message.AddValue(OSCValue.Int(150));

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
- Set Parameter Name  
![imagen](https://github.com/user-attachments/assets/af41bc3f-e97d-4623-a5a5-8aaae45a9edf)  
Set the parameter name by right clicking on desired tab and change to same name of parameter beign sent through OSC
- Select track/s to paramatize and click on "Add Track Volume" if wanting to modify volume level or "Add Fx Param" if wanting to modify value of a parameter of an effect  
![imagen](https://github.com/user-attachments/assets/fedfff7f-708c-4c66-ad95-13122ec345c9)
- Modify curves to desired value response to the parameter  
![imagen](https://github.com/user-attachments/assets/d82d12cf-5d99-4c1a-8819-074287c4759e)

### GoTo
### Scatterer
- Set Parameter Name  
![imagen](https://github.com/user-attachments/assets/91484285-b5b7-4534-9928-995fea85e43a)  
Set the parameter name by right clicking on desired group tab and change to same name of parameter beign sent through OSC

- Set desired min max interval and spawn rate curve  
![imagen](https://github.com/user-attachments/assets/8a0b03f7-30a1-4638-886f-683ae4d9671a)  
Midi notes will be spawned inside the set interval when spawn rate 100%. Spawn rate acts a multiplyer to the interval (50% Spawnrate will double interval values)  

- Select playlist mode  
![imagen](https://github.com/user-attachments/assets/b75a1781-2254-452d-96ff-8824e14c51ed)  
Random will play a random note each time. Shuffle will create a playlist that regenerates after each playthrough  

- Select MIDI notes to be sent to Virtual Keyboard
- Add audio files to desired sampler (If using ReaSamplOmatic items can be quicky added by using Copy/Move Items to Sampler in menu bar)  
![imagen](https://github.com/user-attachments/assets/08b56188-6d39-4913-b9c4-a04918893c02)



## Credits

## License

MIT
