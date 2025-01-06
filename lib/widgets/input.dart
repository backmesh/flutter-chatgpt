import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nimbus/files.dart';
import 'package:nimbus/logger.dart';
import '../user_store.dart';

class InputField extends StatefulWidget {
  final Future<void> Function(
      {required String content, required List<String> filePaths}) onSendMessage;
  const InputField(this.onSendMessage);

  @override
  _InputFieldState createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  String input = '';
  final richTextController = RichTextEditingController();
  bool isStreaming = false;
  StreamSubscription<ChatResult>? subscription;
  late final focusNode = FocusNode(
    onKey: _handleKeyPress,
  );

  KeyEventResult _handleKeyPress(FocusNode focusNode, RawKeyEvent event) {
    // handles submit on enter
    if (event.isKeyPressed(LogicalKeyboardKey.enter) && !event.isShiftPressed) {
      sendMessage();
      // handled means that the event will not propagate
      return KeyEventResult.handled;
    }
    // ignore every other keyboard event including SHIFT+ENTER
    return KeyEventResult.ignored;
  }

  Files filesObj = new Files();
  List<String> files = [];
  List<String> selectedFiles = [];

  Future<void> setFilesInHomeDirectory() async {
    files = await Files.getSupportedFilePaths();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(focusNode);
    });
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  void sendMessage() async {
    if (richTextController.text.trim().replaceAll('\n', '').isNotEmpty) {
      String messageContent = richTextController.text;
      List<String> filePaths =
          List<String>.from(richTextController.selectedFiles);
      richTextController.clear();
      isStreaming = true;
      setState(() {});
      await widget.onSendMessage(
          content: messageContent,
          // Pass a copy as arrays are pass by value in dart
          filePaths: filePaths);
      isStreaming = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RawAutocomplete<String>(
          textEditingController: richTextController,
          focusNode: focusNode,
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.contains('@')) {
              // lazily load files to ask for permissions when it makes sense
              if (files.length == 0) await setFilesInHomeDirectory();
              String query = textEditingValue.text.split('@').last;
              List<String> filteredFiles = files
                  .where((file) =>
                      file.contains(query) && !selectedFiles.contains(file))
                  .toList();
              Logger.debug('Filtered files: $filteredFiles');
              return filteredFiles;
            }
            return const Iterable<String>.empty();
          },
          onSelected: (String selection) {
            // print('onSelected called with: $selection');
            int atIndex = input.lastIndexOf('@');
            String newText = input.substring(0, atIndex + 1) + selection;
            // print('newText: $newText');
            input = newText;
            selectedFiles.add(selection);
            richTextController.updateText(newText, selectedFiles);
            // setState(() {});
          },
          fieldViewBuilder: (BuildContext context,
              TextEditingController fieldTextEditingController,
              FocusNode focusNode,
              VoidCallback onFieldSubmitted) {
            final borderColor = Colors.grey.withOpacity(0.5);
            return TextField(
              controller: fieldTextEditingController,
              focusNode: focusNode,
              onChanged: (text) {
                // print('TextField onChanged called with: $text');
                if (text.isNotEmpty && input.isEmpty ||
                    text.isEmpty && input.isNotEmpty) {
                  input = text;
                  setState(() {});
                } else {
                  input = text;
                }
              },
              onSubmitted: (text) {
                sendMessage();
              },
              style: TextStyle(fontSize: 14.0),
              maxLines: null,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: borderColor),
                ),
                filled: true,
                fillColor: Colors.white,
                hoverColor: Colors.white,
                suffixIcon: AnimatedOpacity(
                  opacity: input.isNotEmpty ? 1.0 : 0.0,
                  duration: Duration(milliseconds: 100),
                  child: isStreaming
                      ? IconButton(
                          iconSize: 20,
                          icon: Icon(Icons.stop_circle),
                          padding: EdgeInsets.all(5),
                          onPressed: () {
                            subscription?.cancel();
                            isStreaming = false;
                            setState(() {});
                          })
                      : IconButton(
                          iconSize: 20,
                          icon: Icon(
                            Icons.send,
                          ),
                          padding: EdgeInsets.all(5),
                          onPressed:
                              input.trim().replaceAll('\n', '').isNotEmpty
                                  ? () => sendMessage()
                                  : null,
                        ),
                ),
              ),
            );
          },
          optionsViewOpenDirection: OptionsViewOpenDirection.up,
          optionsViewBuilder: (BuildContext context,
              AutocompleteOnSelected<String> onSelected,
              Iterable<String> options) {
            Logger.debug('optionsViewBuilder called with options: $options');
            return Align(
              alignment: Alignment.bottomLeft,
              child: Material(
                elevation: 4.0,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: options.length * 50.0,
                  constraints: BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      Logger.debug('Building option: $option');
                      return GestureDetector(
                        onTap: () {
                          Logger.debug('Option tapped: $option');
                          onSelected(option);
                        },
                        child: ListTile(
                          title: Text(
                            option,
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
