// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'integrated_mail.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IntegratedMailAdapter extends TypeAdapter<IntegratedMail> {
  @override
  final int typeId = 1;

  @override
  IntegratedMail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IntegratedMail(
      source: fields[0] as MailSource,
      id: fields[1] as String,
      threadId: fields[2] as String?,
      subject: fields[3] as String,
      sender: fields[4] as String,
      dateTime: fields[5] as DateTime,
      body: fields[6] as String,
      isRead: fields[7] as bool,
      calendarEvents: (fields[8] as List?)?.cast<dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, IntegratedMail obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.source)
      ..writeByte(1)
      ..write(obj.id)
      ..writeByte(2)
      ..write(obj.threadId)
      ..writeByte(3)
      ..write(obj.subject)
      ..writeByte(4)
      ..write(obj.sender)
      ..writeByte(5)
      ..write(obj.dateTime)
      ..writeByte(6)
      ..write(obj.body)
      ..writeByte(7)
      ..write(obj.isRead)
      ..writeByte(8)
      ..write(obj.calendarEvents);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntegratedMailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MailSourceAdapter extends TypeAdapter<MailSource> {
  @override
  final int typeId = 0;

  @override
  MailSource read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MailSource.gmail;
      case 1:
        return MailSource.naver;
      case 2:
        return MailSource.daum;
      default:
        return MailSource.gmail;
    }
  }

  @override
  void write(BinaryWriter writer, MailSource obj) {
    switch (obj) {
      case MailSource.gmail:
        writer.writeByte(0);
        break;
      case MailSource.naver:
        writer.writeByte(1);
        break;
      case MailSource.daum:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MailSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
