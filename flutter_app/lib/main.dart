import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

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
  // This will hold the image data (in bytes) for both mobile and web.
  Uint8List? _imageBytes;
  // Optional: Keep track of the image name for sending it to the backend.
  String? _imageName;
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from the gallery and read its bytes.
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        // Read the image as bytes.
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

  /// Send the image bytes to your Flask backend for analysis.
  Future<void> _analyzeImage() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please pick an image first.")),
      );
      return;
    }

    // Replace with the URL of your Flask backend endpoint.
    final url = Uri.parse('http://localhost:5000/analyze');

    try {
      var request = http.MultipartRequest('POST', url);
      // Attach the image bytes. The field name ('image') must match your backend’s expectations.
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          _imageBytes!,
          filename: _imageName ?? 'image.jpg',
        ),
      );
      var system_prompt =
          "You have to act as a professional doctor, I know you are not but this is for learning purpose. What's in this image?. Do you find anything wrong with it medically? If you make a differential, suggest some remedies for them. Do not add any numbers or special characters in your response. Your response should be in one long paragraph. Also always answer as if you are answering to a real person. Do not say 'In the image I see' but say 'With what I see, I think you have ....'. Do not respond as an AI model in markdown, your answer should mimic that of an actual doctor not an AI bot, Keep your answer concise (max 2 sentences). No preamble, start your answer right away please.";
      request.fields['query'] = "$system_prompt Is there any problem here and what I must do to prevent or avoid this?";

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        print('Analysis success: $responseData');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image analysis successful.")),
        );
      } else {
        print('Analysis failed with status: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Analysis failed.")),
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Pick Image'),
              ),
              SizedBox(height: 20),
              // Display the image using Image.memory.
              _imageBytes != null
                  ? Image.memory(
                      _imageBytes!,
                      height: 300,
                    )
                  : Container(),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _analyzeImage,
                child: Text('Analyse'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
