// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Document _$DocumentFromJson(Map<String, dynamic> json) => Document(
      id: json['id'] as String,
      verificationRequestId: json['verification_request_id'] as String,
      userId: json['userId'] as String,
      type: $enumDecode(_$DocumentTypeEnumMap, json['type']),
      fileName: json['fileName'] as String,
      fileType: json['fileType'] as String,
      fileSize: (json['fileSize'] as num).toInt(),
      fileUrl: json['fileUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      isVerified: json['isVerified'] as bool,
      verificationNotes: json['verificationNotes'] as String?,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$DocumentToJson(Document instance) => <String, dynamic>{
      'id': instance.id,
      'verification_request_id': instance.verificationRequestId,
      'userId': instance.userId,
      'type': _$DocumentTypeEnumMap[instance.type]!,
      'fileName': instance.fileName,
      'fileType': instance.fileType,
      'fileSize': instance.fileSize,
      'fileUrl': instance.fileUrl,
      'thumbnailUrl': instance.thumbnailUrl,
      'isVerified': instance.isVerified,
      'verificationNotes': instance.verificationNotes,
      'uploadedAt': instance.uploadedAt.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$DocumentTypeEnumMap = {
  DocumentType.ID_CARD: 'ID_CARD',
  DocumentType.PASSPORT: 'PASSPORT',
  DocumentType.DRIVERS_LICENSE: 'DRIVERS_LICENSE',
  DocumentType.UTILITY_BILL: 'UTILITY_BILL',
  DocumentType.BANK_STATEMENT: 'BANK_STATEMENT',
  DocumentType.SELFIE: 'SELFIE',
  DocumentType.OTHER: 'OTHER',
};
