import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';

import 'main.dart';

// from soundOutput
import 'package:flutter/services.dart';
import 'package:flutter_midi/flutter_midi.dart';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ControllerPage extends StatelessWidget {
  Future<bool> _save() {
    print('close and disconnect all');
    MidiCommand().teardown();
    return Future.value(true);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: _save,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Controls'),
          ),
          body: MidiControls(),
        ));
  }
}

class MidiControls extends StatefulWidget {
  @override
  MidiControlsState createState() {
    return new MidiControlsState();
  }
}

class MidiControlsState extends State<MidiControls> {
  var _channel = 0;
  var _controller = 0;
  var _value = 0;

  StreamSubscription<List<int>> _rxSubscription;
  MidiCommand _midiCommand = MidiCommand();

  // from soundOutput
  final _flutterMidi = FlutterMidi();

  @override
  void initState() {
    // From soundOutput
    print('init soundOutput');
    load(_pianoFile);
    // end

	
    print('init controller');
    // this is where it reads input!
    _rxSubscription = _midiCommand.onMidiDataReceived.listen((data) {
      print('on data $data');

      // play sound (from soundOutput, now in main)
      _play(60);  

      var status = data[0];

      if (status == 0xF8) {
        print('beat');
        return;
      }

      if (data.length >= 2) {
        var d1 = data[1];
        var d2 = data[2];
        var rawStatus = status & 0xF0; // without channel
        var channel = (status & 0x0F);
        if (rawStatus == 0xB0 && channel == _channel && d1 == _controller) {
          setState(() {
            _value = d2;
          });
        }
      }
    });
    super.initState();
  }

  // load function from soundOutput
  void load(String asset) async {
    print("Loading File ...");
    _flutterMidi.unmute();
    ByteData _byte = await rootBundle.load(asset);
    //assets/sf2/SmallTimGM6mb.sf2
    //assets/sf2/Piano.SF2
    _flutterMidi.prepare(sf2: _byte, name: _pianoFile.replaceAll("assets/", ""));
  }

  String _pianoFile = "assets/Piano.sf2";   // from soundOutput

  // from soundOutput
  void _play(int midi) {
    if (kIsWeb) {
      // WebMidi.play(midi);
      // note from Kevin: we can probably ignore all "kIsWeb" cases
    } else {
      if (_flutterMidi == null) {
        print('badbad');  // lol @ whoever wrote this print statement
      } else {
        _flutterMidi.playMidiNote(midi: midi);
      }
    }
  }

  void dispose() {
    _rxSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: <Widget>[
          SteppedSelector('Channel', _channel + 1, 1, 16, _onChannelChanged),
          SteppedSelector(
              'Controller', _controller, 0, 127, _onControllerChanged),
          SlidingSelector('Value', _value, 0, 127, _onValueChanged),
        ],
      ),
    );
  }

  _onChannelChanged(int newValue) {
    setState(() {
      _channel = newValue - 1;
    });
  }

  _onControllerChanged(int newValue) {
    setState(() {
      _controller = newValue;
    });
  }

  _onValueChanged(int newValue) {
    setState(() {
      _value = newValue;
      CCMessage(channel: _channel, controller: _controller, value: _value)
          .send();
    });
  }
}

class SteppedSelector extends StatelessWidget {
  final String label;
  final int minValue;
  final int maxValue;
  final int value;
  final Function(int) callback;

  SteppedSelector(
      this.label, this.value, this.minValue, this.maxValue, this.callback);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(label),
        IconButton(
            icon: Icon(Icons.remove_circle),
            onPressed: (value > minValue)
                ? () {
                    callback(value - 1);
                  }
                : null),
        Text(value.toString()),
        IconButton(
            icon: Icon(Icons.add_circle),
            onPressed: (value < maxValue)
                ? () {
                    callback(value + 1);
                  }
                : null)
      ],
    );
  }
}

class SlidingSelector extends StatelessWidget {
  final String label;
  final int minValue;
  final int maxValue;
  final int value;
  final Function(int) callback;

  SlidingSelector(
      this.label, this.value, this.minValue, this.maxValue, this.callback);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(label),
        Slider(
          value: value.toDouble(),
          divisions: maxValue,
          min: minValue.toDouble(),
          max: maxValue.toDouble(),
          onChanged: (v) {
            callback(v.toInt());
          },
        ),
        Text(value.toString()),
      ],
    );
  }
}


