import 'package:flutter/material.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:nimbus/user_store.dart';

class InputTags extends StatefulWidget {
  final Map<String, Tag> tags;
  final String entryKey;
  final Entry entry;
  const InputTags(this.tags, this.entryKey, this.entry);

  @override
  State<InputTags> createState() => _InputTagsState();
}

class _InputTagsState extends State<InputTags> {
  bool _isFocused = false;
  FocusNode? _autoCompletefocusNode;

  void _trackFocus() {
    if (_autoCompletefocusNode != null &&
        _autoCompletefocusNode!.hasFocus != _isFocused) {
      setState(() {
        _isFocused = _autoCompletefocusNode!.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    if (_autoCompletefocusNode != null) {
      _autoCompletefocusNode!.removeListener(_trackFocus);
      // let autocomplete manage disposal
      _autoCompletefocusNode = null;
    }
    super.dispose();
  }

  Future<void> _tagEntry(String tagId) async {
    if (!widget.entry.tagIds.contains(tagId)) {
      widget.entry.tagIds.add(tagId);
      await UserStore.instance.saveEntry(widget.entryKey, widget.entry);
      await Posthog().capture(
        eventName: 'TagEntry',
      );
    }
  }

  Future<void> _untagEntry(String tagId) async {
    if (widget.entry.tagIds.remove(tagId)) {
      await UserStore.instance.saveEntry(widget.entryKey, widget.entry);
      await Posthog().capture(
        eventName: 'UntagEntry',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Column(children: [
      Autocomplete<MapEntry<String, Tag>>(
          displayStringForOption: (MapEntry<String, Tag> option) =>
              option.value.name,
          optionsViewBuilder: (context, onSelected, options) {
            return Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 1.0),
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.all(Radius.circular(10.0)),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxHeight: 150, maxWidth: 150),
                  child: ListView.builder(
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final MapEntry<String, Tag> option =
                          options.elementAt(index);
                      return TextButton(
                        onPressed: () async {
                          onSelected(option);
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Text(
                              '${option.value.name}',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text == '') {
              final _filteredSuggestions = {
                for (var entry in widget.tags.entries)
                  if (!widget.entry.tagIds.contains(entry.key))
                    entry.key: entry.value
              };
              return _filteredSuggestions.entries;
            }
            final query = textEditingValue.text.toLowerCase();
            final _filteredSuggestions = {
              for (var entry in widget.tags.entries)
                if (!widget.entry.tagIds.contains(entry.key) &&
                    entry.value.name.toLowerCase().contains(query))
                  entry.key: entry.value
            };
            return _filteredSuggestions.entries
                .followedBy([MapEntry('create', Tag(name: query))]);
          },
          onSelected: (MapEntry<String, Tag> selectedEntry) async {
            if (selectedEntry.key == 'create') {
              final doc = await UserStore.instance.newTag(selectedEntry.value);
              return await _tagEntry(doc.id);
            }
            await _tagEntry(selectedEntry.key);
          },
          fieldViewBuilder: (context, ttec, tfn, onFieldSubmitted) {
            _autoCompletefocusNode = tfn;
            tfn.addListener(_trackFocus);
            if (!_isFocused) ttec.clear();
            return Row(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 100),
                  width: _isFocused && screenWidth > 400 ? 200 : 100,
                  height: 40,
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 4.0),
                  child: TextField(
                    onSubmitted: (value) async {
                      var entries = widget.tags.entries
                          .where((el) => el.value.name.toLowerCase() == value)
                          .toList();
                      var entry = entries.length == 1 ? entries.single : null;
                      if (entry == null) {
                        final doc =
                            await UserStore.instance.newTag(Tag(name: value));
                        await _tagEntry(doc.id);
                      } else {
                        await _tagEntry(entry.key);
                      }
                    },
                    style: TextStyle(
                      fontSize: 12.0,
                    ),
                    controller: ttec,
                    focusNode: tfn,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor:
                          _isFocused ? Colors.grey[200] : Colors.transparent,
                      hintText: '+ Tag',
                      hintStyle:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15.0, vertical: 5.0),
                    ),
                  ),
                ),
                ...widget.entry.tagIds.reversed.map((String tagId) {
                  final tag = widget.tags[tagId]!;
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.circular(20.0),
                      ),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 5.0, vertical: 3.0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5.0, vertical: 5.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const SizedBox(width: 4.0),
                        Text(
                          '${tag.name}',
                          style: TextStyle(fontSize: 12.0, color: Colors.white),
                        ),
                        const SizedBox(width: 4.0),
                        InkWell(
                          child: const Icon(
                            Icons.cancel,
                            size: 14.0,
                            color: Color.fromARGB(255, 233, 233, 233),
                          ),
                          onTap: () {
                            _untagEntry(tagId);
                          },
                        )
                      ],
                    ),
                  );
                }).toList(),
              ],
            );
          })
    ]);
  }
}
