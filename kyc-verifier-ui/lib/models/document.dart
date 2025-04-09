import 'package:json_annotation/json_annotation.dart';
// Using the same enum from verification_request.dart
import 'verification_request.dart';

// NOTE: After changing this file, run the following command to regenerate the .g.dart file:
// flutter pub run build_runner build --delete-conflicting-outputs

part 'document.g.dart';

@JsonSerializable()
class Document {
  final String id;
  @JsonKey(name: 'verification_request_id')
  final String verificationRequestId;
  final String userId;
  final DocumentType type;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String fileUrl;
  final String? thumbnailUrl;
  final bool isVerified;
  final String? verificationNotes;
  final DateTime uploadedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Document({
    required this.id,
    required this.verificationRequestId,
    required this.userId,
    required this.type,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.fileUrl,
    this.thumbnailUrl,
    required this.isVerified,
    this.verificationNotes,
    required this.uploadedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) => _$DocumentFromJson(json);
  Map<String, dynamic> toJson() => _$DocumentToJson(this);
}
