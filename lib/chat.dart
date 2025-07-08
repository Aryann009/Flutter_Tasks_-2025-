import 'package:flutter/material.dart';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatScreen extends StatefulWidget{
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();

}

final apiKey = dotenv.env['GEMINI_API_KEY'];

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  File? _selectedImage;
  bool _isLoading = false;
  late GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey!);
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty && _selectedImage == null) {
      return;
    }
    setState(() {
      _messages.add(ChatMessage(
        text : message,
        isUser : true,
        image: _selectedImage,
      ));
      _messageController.clear();
      _isLoading = true;
    });
    try{
      final parts = <Part>[];

      if (_selectedImage != null){
        final imageBytes = await _selectedImage!.readAsBytes();
        parts.add(DataPart('image/jpeg', Uint8List.fromList(imageBytes),
        ));
      }
      parts.add(TextPart(message.isNotEmpty ? message : 'Describe Image'));

      final response = await _model.generateContent([
        Content.multi(parts),
      ]);
      setState(() {
        _messages.add(ChatMessage(
          text: response.text ?? 'No response',
          isUser: false,
        ));
      });
    } catch(e){
      debugPrint('Error: $e');
      setState(() {
        _messages.add(ChatMessage(
          text: 'Error : ${e.toString()}',
          isUser: false,
        ));
      });
    } finally{
      setState(() {
        _selectedImage = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini Chat Bot'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _ChatBubble(
                message: _messages[index],
              ),
            ),
          ),
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _pickImage,
                ),
                if (_selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: SizedBox(
                      height: 40,
                      width: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4.0),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      hintText: 'Enter message...',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendMessage, ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage{
  final String text;
  final bool isUser;
  final File? image;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.image,
  });
}

class _ChatBubble extends StatelessWidget{
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        constraints: BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Text(message.text),
      ),
    );
  }
}