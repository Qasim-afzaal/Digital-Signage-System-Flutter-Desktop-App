import 'dart:convert';

PlayerMediaModel playListModelFromJson(String str) => PlayerMediaModel.fromJson(json.decode(str));

String PlayerMediaModelToJson(PlayerMediaModel data) => json.encode(data.toJson());

class PlayerMediaModel {
  String action;
  Data data;
  String sender;

  PlayerMediaModel({
    required this.action,
    required this.data,
    required this.sender,
  });

  factory PlayerMediaModel.fromJson(Map<String, dynamic> json) => PlayerMediaModel(
        action: json["action"],
        data: Data.fromJson(json["data"]),
        sender: json["sender"],
      );

  Map<String, dynamic> toJson() => {
        "action": action,
        "data": data.toJson(),
        "sender": sender,
      };
}

class Data {
  bool success;
  String message;
  String playbackType;
  List<Playlist> playlist;

  Data({
    required this.success,
    required this.message,
    required this.playbackType,
    required this.playlist,
  });

factory Data.fromJson(Map<String, dynamic> json) => Data(
      success: json["success"],
      message: json["message"],
      playbackType: json["playback_type"],
      playlist: json["playlists"] != null
          ? List<Playlist>.from(json["playlists"].map((x) => Playlist.fromJson(x)))
          : [], // Provide an empty list if null
    );

  Map<String, dynamic> toJson() => {
        "success": success,
        "message": message,
        "playback_type": playbackType,
        "playlists": List<dynamic>.from(playlist.map((x) => x.toJson())),
      };
}

class Playlist {
  String name;
  String id;
    String playbackType;
  SchedulePlaylist? playlistSchedule;
  Playback? playback;
  Default? playlistDefault;
  List<Media>? media;
  bool isPaused;

  Playlist({
    required this.name,
    required this.id,
    this.playlistSchedule,
    required this.playbackType,
    this.playback,
    this.playlistDefault,
    this.media,
    required this.isPaused,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        name: json["name"],
        id: json["id"],
        playlistSchedule: json["playlist_schedule"] != null
            ? SchedulePlaylist.fromJson(json["playlist_schedule"])
            : null,
            playbackType: json["playback_type"],
        playback: json["playback"] != null ? Playback.fromJson(json["playback"]) : null,
        playlistDefault: json["default"] != null ? Default.fromJson(json["default"]) : null,
        media: json["media"] != null
            ? List<Media>.from(json["media"].map((x) => Media.fromJson(x)))
            : null,
        isPaused: json["is_paused"],
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "id": id,
        "playlist_schedule": playlistSchedule?.toJson(),
        "playback": playback?.toJson(),
        "default": playlistDefault?.toJson(),
        "media": media != null ? List<dynamic>.from(media!.map((x) => x.toJson())) : null,
        "is_paused": isPaused,
      };
}

class Media {
  Default settings;
  SchedulePlaylist schedule;
  String mediaType;
  String mediaUrl;

  Media({
    required this.settings,
    required this.schedule,
    required this.mediaType,
    required this.mediaUrl,
  });

  factory Media.fromJson(Map<String, dynamic> json) => Media(
        settings: Default.fromJson(json["settings"]),
        schedule: SchedulePlaylist.fromJson(json["schedule"]),
        mediaType: json["mediaType"],
        mediaUrl: json["mediaUrl"],
      );

  Map<String, dynamic> toJson() => {
        "settings": settings.toJson(),
        "schedule": schedule.toJson(),
        "mediaType": mediaType,
        "mediaUrl": mediaUrl,
      };
}

class SchedulePlaylist {
  bool alwaysPlay;
  Period? period;

  SchedulePlaylist({
    required this.alwaysPlay,
    this.period,
  });

  factory SchedulePlaylist.fromJson(Map<String, dynamic> json) => SchedulePlaylist(
        alwaysPlay: json["always_play"],
        period: json.containsKey("period") && json["period"] != null
            ? Period.fromJson(json["period"])
            : null,
      );

  Map<String, dynamic> toJson() => {
        "always_play": alwaysPlay,
        "period": period?.toJson(),
      };
}

class Period {
  Days days;
  Time time;
  Date date;

  Period({
    required this.days,
    required this.time,
    required this.date,
  });

  factory Period.fromJson(Map<String, dynamic> json) => Period(
        days: Days.fromJson(json["days"]),
        time: Time.fromJson(json["time"]),
        date: Date.fromJson(json["date"]),
      );

  Map<String, dynamic> toJson() => {
        "days": days.toJson(),
        "time": time.toJson(),
        "date": date.toJson(),
      };
}

class Date {
  DateTime start;
  DateTime end;

  Date({
    required this.start,
    required this.end,
  });

  factory Date.fromJson(Map<String, dynamic> json) {
    DateTime startDate = _parseDate(json["start"]);

    // Calculate the next 5 days from the start date
    DateTime endDate = json["end"] != null ? _parseDate(json["end"]) : startDate.add(Duration(days: 5));

    return Date(
      start: startDate,
      end: endDate,
    );
  }

  // Helper method to handle different date formats
  static DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      // Attempt to fix malformed date strings
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2].padLeft(2, '0')), // Add leading zero if missing
        );
      }
      throw FormatException('Invalid date format: $dateStr');
    }
  }

  Map<String, dynamic> toJson() => {
        "start": "${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}",
        "end": "${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}",
      };
}

class Days {
  bool monday;
  bool tuesday;
  bool wednesday;
  bool thursday;
  bool friday;
  bool saturday;
  bool sunday;

  Days({
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
  });

  factory Days.fromJson(Map<String, dynamic> json) => Days(
        monday: json["monday"],
        tuesday: json["tuesday"],
        wednesday: json["wednesday"],
        thursday: json["thursday"],
        friday: json["friday"],
        saturday: json["saturday"],
        sunday: json["sunday"],
      );

  Map<String, dynamic> toJson() => {
        "monday": monday,
        "tuesday": tuesday,
        "wednesday": wednesday,
        "thursday": thursday,
        "friday": friday,
        "saturday": saturday,
        "sunday": sunday,
      };
}

class Time {
  String from;
  String to;

  Time({
    required this.from,
    required this.to,
  });

  factory Time.fromJson(Map<String, dynamic> json) => Time(
        from: json["from"],
        to: json["to"],
      );

  Map<String, dynamic> toJson() => {
        "from": from,
        "to": to,
      };
}

class Default {
  String duration;
  String transition;
  String? volume;
  bool isPaused;
  String? otherMediaDefaultVolume;
  String? ratio;

  Default({
    required this.duration,
    required this.transition,
    required this.isPaused,
    required this.volume,
    this.otherMediaDefaultVolume,
    this.ratio,
  });

  factory Default.fromJson(Map<String, dynamic> json) => Default(
        duration: json["duration"],
        transition: json["transition"],
        volume: json["volume"] ?? null,
        isPaused: json["is_paused"] ?? false,
        otherMediaDefaultVolume: json["other_media_default_volume"],
        ratio: json["ratio"],
      );

  Map<String, dynamic> toJson() => {
        "duration": duration,
        "transition": transition,
        "volume": volume,
        "is_paused": isPaused,
        "other_media_default_volume": otherMediaDefaultVolume,
        "ratio": ratio,
      };
}

class Playback {
  String mode;
  int count;
  String order;

  Playback({
    required this.mode,
    required this.count,
    required this.order,
  });

  factory Playback.fromJson(Map<String, dynamic> json) => Playback(
        mode: json["mode"],
        count: json["count"],
        order: json["order"],
      );

  Map<String, dynamic> toJson() => {
        "mode": mode,
        "count": count,
        "order": order,
      };
}
