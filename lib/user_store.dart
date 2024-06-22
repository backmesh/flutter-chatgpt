import 'dart:convert';
import 'dart:math';

import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_quill/quill_delta.dart';

class Tag {
  final String name;
  final String color;
  static final List<String> _colors = ['#ffff'];

  Tag({required this.name, required this.color});

  static List<String> getNames(List<Tag> tags) {
    return tags.map((tag) => tag.name).toList();
  }

  static String getRandomColor() {
    final random = new Random();
    final i = random.nextInt(_colors.length);
    return _colors[i];
  }

  Tag.fromDb(String key, Map<String, Object?> json)
      : this(
          name: json['name']! as String,
          color: json['color']! as String,
        );

  Map<String, Object?> toDb() {
    return {
      'name': name,
      'color': color,
    };
  }
}

class Entry {
  final Document doc;
  final DateTime date;
  final List<String> tagIds;

  Entry({required this.doc, required this.date, required this.tagIds});

  static List<String> _tagIdsMapper(Object? jsonField) => jsonField != null
      ? (jsonField as List<dynamic>).cast<String>()
      : [].cast<String>();

  Entry.fromDb(Map<String, Object?> json)
      : this(
          doc: _deltaToDoc(json['delta']! as String),
          date: (json['date']! as Timestamp)
              .toDate(), // DateTime.parse(json['date']! as String), //
          tagIds: _tagIdsMapper(json['tagIds']),
        );

  Map<String, Object?> toDb() {
    return {
      'delta': _docToDelta(doc),
      // use UTC in database which is just use for query ordering and not for display in UI
      'date': Timestamp.fromDate(DateTime.utc(date.year, date.month, date.day)),
      'tagIds': tagIds
    };
  }

  Entry fromNewDoc(Document newDoc) {
    return Entry(date: date, doc: newDoc, tagIds: tagIds);
  }

  static Document _deltaToDoc(String delta) {
    return Document.fromDelta(Delta.fromJson(jsonDecode(delta)));
  }

  static String _docToDelta(Document doc) {
    return jsonEncode(doc.toDelta().toJson());
  }
}

class UserStore {
  final String uid;
  final CollectionReference<Entry> entriesRef;
  final CollectionReference<Tag> tagsRef;

  static UserStore? _instance;

  UserStore._(this.uid, this.entriesRef, this.tagsRef);

  factory UserStore(String uid) {
    final tagsRef = FirebaseFirestore.instance
        .collection('journalists/${uid}/tags')
        .withConverter<Tag>(
          fromFirestore: (snapshot, _) =>
              Tag.fromDb(snapshot.id, snapshot.data()!),
          toFirestore: (tag, _) => tag.toDb(),
        );
    final entriesRef = FirebaseFirestore.instance
        .collection('journalists/${uid}/entries')
        .withConverter<Entry>(
          fromFirestore: (snapshot, _) {
            return Entry.fromDb(snapshot.data()!);
          },
          toFirestore: (entry, _) => entry.toDb(),
        );
    _instance ??= UserStore._(uid, entriesRef, tagsRef);
    return _instance!;
  }

  static void clear() {
    _instance = null;
  }

  static UserStore get instance {
    assert(_instance != null, 'UserStore must be initialized before accessing');
    return _instance!;
  }

  Query<Entry> readEntries() {
    return entriesRef.orderBy('date', descending: true);
  }

  Future<void> deleteEntry(Entry entry) async {
    entriesRef.doc(entry.date.toIso8601String()).delete();
  }

  Future<void> saveEntry(Entry entry) async {
    await entriesRef.doc(entry.date.toIso8601String()).set(entry);
  }

  Future<DocumentReference<Tag>> newTag(Tag tag) async {
    return await tagsRef.add(tag);
  }
}
