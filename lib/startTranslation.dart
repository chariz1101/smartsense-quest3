import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
// **CRITICAL FIX: Replacing faulty import with the correct 'record' package**
import 'package:record/record.dart'; 
import 'package:web_socket_channel/io.dart';
import 'package:permission_handler/permission_handler.dart';

// --- CONFIGURATION ---
// IMPORTANT: Replace this with the IP address and port of your Python server.
const String websocketUrl = 'wss://quest-transcriber-523298308672.asia-southeast1.run.app'; 

// Audio settings must match the server's expectation 
const int sampleRate = 16000;
const int channels = 1; // Mono
// --- END CONFIGURATION ---

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  IOWebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _micSubscription;
  final AudioRecorder _audioRecorder = AudioRecorder(); // Instance of AudioRecorder
  
  String _status = 'Initializing...';
  String _transcribedText = ''; 
  String _interimText = ''; 

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndConnect();
  }

  // 1. Request Microphone Permission and Start Connection Attempt
  Future<void> _requestPermissionsAndConnect() async {
    setState(() => _status = 'Requesting Mic Permission...');
    
    // 1. Request microphone permission
    final status = await Permission.microphone.request();
    
    if (status.isGranted) {
      // FIX: Removed the incomplete line that caused the 'is' error.
      // Permission is granted, so we proceed directly to connection.
      
      _connectWebSocket();
    } else {
      setState(() => _status = 'Mic Permission Denied. Cannot start streaming.');
      if (status.isPermanentlyDenied) {
        debugPrint('Microphone permission permanently denied. Please enable in Quest settings.');
      }
    }
  }

  // 2. WebSocket Connection and Listener
  void _connectWebSocket() {
    try {
      _channel = IOWebSocketChannel.connect(Uri.parse(websocketUrl));
      setState(() => _status = 'Connecting to Server...');
      
      _channel!.stream.listen(
        (message) {
          _handleTranscription(message.toString());
        },
        onDone: () {
          setState(() {
            _status = 'Disconnected (Server Closed)';
            _stopStreaming();
          });
        },
        onError: (error) {
          setState(() {
            _status = 'Connection Error. Retrying in 5s...';
            _stopStreaming();
            Future.delayed(const Duration(seconds: 5), _connectWebSocket);
          });
          debugPrint('WebSocket Error: $error');
        },
      );

      setState(() => _status = 'Connected. Ready to start streaming.');

    } catch (e) {
      setState(() => _status = 'Failed to connect: $e. Retrying in 5s...');
      Future.delayed(const Duration(seconds: 5), _connectWebSocket);
      debugPrint('Connection failed: $e');
    }
  }

  // 3. Handle incoming transcription messages
  void _handleTranscription(String message) {
    if (mounted) {
      // Logic for determining final vs. interim results
      if (message.endsWith('.') || message.endsWith('?') || message.endsWith('!')) {
        setState(() {
          _transcribedText += '$_interimText $message\n'; // Append final result
          _interimText = ''; // Clear interim
        });
      } else {
        setState(() {
          _interimText = message; // Update the real-time interim result
        });
      }
    }
  }

  // 4. Start Microphone and Stream to WebSocket
  Future<void> _startStreaming() async {
    if (_channel == null || _status.contains('Connected') == false) {
      _connectWebSocket();
      if (_status.contains('Connected') == false) return;
    }

    // Check if recording is already active
    if (await _audioRecorder.isRecording()) return; 

    try {
      // Configure and start recording raw bytes (startStream is the key method)
      final micStream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits, // 16-bit PCM is critical for ASR
          sampleRate: sampleRate,
          numChannels: channels,
        ),
      );

      _micSubscription = micStream.listen((audioChunk) {
        // Send raw binary data (Uint8List)
        _channel!.sink.add(audioChunk); 
      }, onError: (e) {
        setState(() => _status = 'Mic Stream Error: $e');
        _stopStreaming();
      });

      setState(() {
        _status = 'Streaming Audio...';
        _transcribedText = ''; 
        _interimText = '';
        // Send a control command to the server to signal the start of a stream
        _channel!.sink.add('START_STREAMING'); 
      });

    } catch (e) {
      setState(() => _status = 'Audio stream setup failed: $e');
      _stopStreaming();
      debugPrint('Audio stream setup failed: $e');
    }
  }

  // 5. Stop Streaming and Clean Up
  void _stopStreaming() async {
    _micSubscription?.cancel();
    _micSubscription = null;
    await _audioRecorder.stop(); // Stop the audio stream using the record API
    
    if (_channel != null && _status.contains('Connected')) {
      // Send a control command to the server to signal the end of a stream
      _channel!.sink.add('STOP_STREAMING'); 
    }
    
    if (mounted) {
      setState(() {
        _status = 'Ready to Start';
        if (_interimText.isNotEmpty) {
          // If there's pending interim text, finalize it
          _transcribedText += '$_interimText (Stopped)\n';
          _interimText = '';
        }
      });
    }
  }
  
  @override
  void dispose() {
    _stopStreaming();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if the recorder is actively streaming (we use the subscription status)
    final isStreaming = _micSubscription != null; 
    final isConnected = _status.contains('Connected') && !isStreaming;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest 3 Real-time ASR'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Status Indicator
            Text(
              'Status: $_status', 
              style: TextStyle(
                color: _status.contains('Error') || _status.contains('Denied') ? Colors.redAccent : Colors.lightGreenAccent,
                fontWeight: FontWeight.bold
              )
            ),
            const SizedBox(height: 16),
            
            // Real-time Interim Text Display (Highlight for VR viewing)
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isStreaming ? Colors.yellow.shade700 : Colors.blueGrey.shade800,
                  width: isStreaming ? 3 : 1,
                ),
              ),
              child: Text(
                _interimText.isEmpty && !isStreaming
                    ? 'Press START to speak...'
                    : _interimText.isEmpty
                        ? '...Listening...'
                        : _interimText,
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.w500,
                  color: isStreaming ? Colors.yellowAccent : Colors.blueGrey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 24),
            const Text(
              'Transcript History:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            
            // Final Transcribed Text History
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(top: 8),
                child: SingleChildScrollView(
                  child: Text(
                    _transcribedText.isEmpty ? 'The full transcription will appear here.' : _transcribedText,
                    style: const TextStyle(fontSize: 18, color: Colors.white70, height: 1.5),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // Start/Stop Button
            Center(
              child: ElevatedButton.icon(
                onPressed: isStreaming ? _stopStreaming : isConnected ? _startStreaming : null,
                icon: Icon(isStreaming ? Icons.stop : Icons.mic, size: 30),
                label: Text(
                  isStreaming ? 'STOP STREAMING' : 'START STREAMING',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isStreaming ? Colors.redAccent.shade700 : isConnected ? Colors.green.shade700 : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}