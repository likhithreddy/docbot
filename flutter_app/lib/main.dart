import 'dart:async';
import 'dart:convert'; // For jsonEncode and base64 encoding.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Docbot',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ImagePickerScreen(),
    );
  }
}

class ImagePickerScreen extends StatefulWidget {
  @override
  _ImagePickerScreenState createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends State<ImagePickerScreen> {
  // For image handling.
  Uint8List? _imageBytes;
  String? _imageName;
  final ImagePicker _picker = ImagePicker();

  // For speech-to-text.
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _recognizedText = ""; // Final text displayed after stopping.
  String _tempText = ""; // Temporary storage while listening.
  Timer? _listeningTimer;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  /// Pick an image from the gallery.
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageName = pickedFile.name;
        });
      } else {
        print('No image selected.');
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  /// Toggle listening. When started, listen for up to 10 seconds or until tapped again.
  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => print("Speech status: $status"),
        onError: (errorNotification) =>
            print("Speech error: $errorNotification"),
      );
      if (available) {
        setState(() {
          _isListening = true;
          _tempText = "";
          _recognizedText = "";
        });
        _speech.listen(
          onResult: (result) {
            // Update temporary text while listening.
            _tempText = result.recognizedWords;
          },
          listenMode: stt.ListenMode.confirmation,
          partialResults: true,
          cancelOnError: false,
        );
        // Auto-stop after 10 seconds.
        _listeningTimer = Timer(Duration(seconds: 10), () {
          if (_isListening) {
            _stopListening();
          }
        });
      }
    } else {
      _stopListening();
    }
  }

  /// Stops listening and updates the displayed transcribed text.
  void _stopListening() {
    _speech.stop();
    if (_listeningTimer != null) {
      _listeningTimer!.cancel();
      _listeningTimer = null;
    }
    setState(() {
      _isListening = false;
      _recognizedText = _tempText;
    });
  }

  /// Send the image and the transcribed query directly to the Groq API.
  Future<void> _analyzeImageDirectly() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please pick an image first.")),
      );
      return;
    }

    // Use the transcribed text as the query; if empty, use a default query.
    String queryText = _recognizedText.isNotEmpty
        ? _recognizedText
        : "Is there any problem here?";
    String model = "llama-3.2-90b-vision-preview";

    // Encode the image bytes to base64.
    String base64Image = base64Encode(_imageBytes!);
    // Construct the data URI string; adjust the MIME type if needed.
    String imageDataUri = "data:image/jpeg;base64,$base64Image";

    // Build the JSON payload.
    Map<String, dynamic> payload = {
      "model": model,
      "messages": [
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text": queryText,
            },
            {
              "type": "image_url",
              "image_url": {"url": imageDataUri},
            },
          ],
        }
      ]
    };

    // Groq API endpoint.
    final url = Uri.parse("https://api.groq.com/openai/v1/chat/completions");
    const String groqApiKey =
        "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";

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $groqApiKey",
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        // Assuming the API returns a structure similar to:
        // { "choices": [ { "message": { "content": "<result>" } } ] }
        final result = responseJson["choices"][0]["message"]["content"];
        print("Analysis success: $result");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Analysis success: $result")),
        );
      } else {
        print("Analysis failed with status: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Analysis failed: ${response.statusCode}")),
        );
      }
    } catch (e) {
      print("Error occurred while analyzing image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error occurred while analyzing image.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Docbot App'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Pick Image'),
              ),
              SizedBox(height: 20),
              // Display the picked image.
              _imageBytes != null
                  ? Image.memory(
                      _imageBytes!,
                      height: 300,
                    )
                  : Container(),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _toggleListening,
                child: Text(_isListening ? 'Stop' : 'Record Query'),
              ),
              SizedBox(height: 10),
              // Display transcribed text only after listening stops.
              (!_isListening && _recognizedText.isNotEmpty)
                  ? TextFormField(
                      initialValue: _recognizedText,
                      decoration: InputDecoration(
                        labelText: "Enter Query",
                        border: OutlineInputBorder(),
                      ),
                      style: TextStyle(fontSize: 16),
                    )
                  : Container(),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _analyzeImageDirectly,
                child: Text('Analyse'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
