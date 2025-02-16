import 'dart:convert';

MultiMediaModel campaignModelFromJson(String str) =>
    MultiMediaModel.fromJson(json.decode(str));

String campaignModelToJson(MultiMediaModel data) => json.encode(data.toJson());

class MultiMediaModel {
  String action;
  String sender;
  Data data;

  MultiMediaModel({
    required this.action,
    required this.sender,
    required this.data,
  });

  factory MultiMediaModel.fromJson(Map<String, dynamic> json) => MultiMediaModel(
        action: json["action"],
        sender: json["sender"],
        data: Data.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "action": action,
        "sender": sender,
        "data": data.toJson(),
      };
}

class Data {
  bool success;
  String message;
  List<PlayerCampaign> playerCampaigns;

  Data({
    required this.success,
    required this.message,
    required this.playerCampaigns,
  });

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        success: json["success"],
        message: json["message"],
        playerCampaigns: List<PlayerCampaign>.from(
            json["playerCampaigns"].map((x) => PlayerCampaign.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "success": success,
        "message": message,
        "playerCampaigns":
            List<dynamic>.from(playerCampaigns.map((x) => x.toJson())),
      };
}

class PlayerCampaign {
  String playbackType;
  String campaignId;
  String campaignName;
  Resolution resolution;
  CampaignSchedule campaignSchedule;
  CampaignSettings campaignSettings;
  List<Zone> zones;

  PlayerCampaign({
    required this.playbackType,
    required this.campaignId,
    required this.campaignName,
    required this.resolution,
    required this.campaignSchedule,
    required this.campaignSettings,
    required this.zones,
  });

  factory PlayerCampaign.fromJson(Map<String, dynamic> json) => PlayerCampaign(
        playbackType: json["playback_type"],
        campaignId: json["campaign_id"],
        campaignName: json["campaign_name"],
        resolution: Resolution.fromJson(json["resolution"]),
        campaignSchedule: CampaignSchedule.fromJson(json["campaign_schedule"]),
        campaignSettings: CampaignSettings.fromJson(json["campaign_settings"]),
        zones: List<Zone>.from(json["zones"].map((x) => Zone.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "playback_type": playbackType,
        "campaign_id": campaignId,
        "resolution": resolution.toJson(),
        "campaign_schedule": campaignSchedule.toJson(),
        "campaign_settings": campaignSettings.toJson(),
        "zones": List<dynamic>.from(zones.map((x) => x.toJson())),
      };
}

class CampaignSchedule {
  bool alwaysPlay;
  Period? period;

  CampaignSchedule({
    required this.alwaysPlay,
    this.period,
  });

  factory CampaignSchedule.fromJson(Map<String, dynamic> json) =>
      CampaignSchedule(
        alwaysPlay: json["always_play"],
        period:
            json["period"] != null ? Period.fromJson(json["period"]) : null,
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

class Date {
  String start;
  String? end;

  Date({
    required this.start,
    this.end,
  });

  factory Date.fromJson(Map<String, dynamic> json) {
    // Get the current date
    DateTime currentDate = DateTime.now();
    
    // Calculate the next 5 days
    DateTime nextFiveDays = currentDate.add(Duration(days: 5));
    
    // Format the date to ISO8601 string (or any format you require)
    String nextFiveDaysFormatted = nextFiveDays.toIso8601String();

    // Check if end date is null and set to the next 5 days if it is
    String? endDate = json["end"];
    endDate ??= nextFiveDaysFormatted;

    return Date(
      start: json["start"],
      end: endDate,
    );
  }

  Map<String, dynamic> toJson() => {
        "start": start,
        "end": end,
      };
}


class CampaignSettings {
  String transition;
  String duration;
  bool loop;

  CampaignSettings({
    required this.transition,
    required this.duration,
    required this.loop,
  });

  factory CampaignSettings.fromJson(Map<String, dynamic> json) =>
      CampaignSettings(
        transition: json["transition"],
        duration: json["duration"],
        loop: json["loop"],
      );

  Map<String, dynamic> toJson() => {
        "transition": transition,
        "duration": duration,
        "loop": loop,
      };
}

class Resolution {
  Resolution();

  factory Resolution.fromJson(Map<String, dynamic> json) => Resolution();

  Map<String, dynamic> toJson() => {};
}

class Zone {
  int id;
  int x;
  int y;
  int width;
  int height;
  List<MediaItem> mediaItems;

  Zone({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.mediaItems,
  });

  factory Zone.fromJson(Map<String, dynamic> json) => Zone(
        id: json["id"],
        x: json["x"],
        y: json["y"],
        width: json["width"],
        height: json["height"],
        mediaItems: List<MediaItem>.from(
            json["mediaItems"].map((x) => MediaItem.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "x": x,
        "y": y,
        "width": width,
        "height": height,
        "mediaItems": List<dynamic>.from(mediaItems.map((x) => x.toJson())),
      };
}

class MediaItem {
  String id;
  String mediaType;
  String mediaUrl;
  Settings settings;
  CampaignSchedule schedule;

  MediaItem({
    required this.id,
    required this.mediaType,
    required this.mediaUrl,
    required this.settings,
    required this.schedule,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json["id"],
        mediaType: json["mediaType"],
        mediaUrl: json["mediaUrl"],
        settings: Settings.fromJson(json["settings"]),
        schedule: CampaignSchedule.fromJson(json["schedule"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "mediaType": mediaType,
        "mediaUrl": mediaUrl,
        "settings": settings.toJson(),
        "schedule": schedule.toJson(),
      };
}

class Settings {
  String duration;
  String transition;
  bool loop;

  Settings({
    required this.duration,
    required this.transition,
    required this.loop,
  });

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        duration: json["duration"],
        transition: json["transition"],
        loop: json["loop"],
      );

  Map<String, dynamic> toJson() => {
        "duration": duration,
        "transition": transition,
        "loop": loop,
      };
}
