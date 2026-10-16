/// Mirrors backend's WorkerScheduleDtos (backend/workforce/.../WorkerScheduleDtos.java).
library;

import 'package:flutter/material.dart';

/// One person who works at the business, whichever directory they were added through.
class WorkerSummary {
  final String id;

  /// MASTER / MECHANIC / CLEANER / STAFF.
  final String kind;
  final String displayName;
  final String? photoUrl;
  final bool active;

  /// True when the owner gave them their own weekly schedule (otherwise they use the shared slots).
  final bool scheduleConfigured;

  /// End of the time off in effect right now, if any.
  final DateTime? offUntil;

  /// Mean of the ratings on this person's bookings; null until their first review (absent, not zero).
  final double? averageRating;
  final int reviewCount;

  const WorkerSummary({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.photoUrl,
    required this.active,
    required this.scheduleConfigured,
    required this.offUntil,
    this.averageRating,
    this.reviewCount = 0,
  });

  /// Reviews a person needs before customers see them under "Best masters" (mirrors the backend rule).
  static const reviewsToQualify = 3;

  factory WorkerSummary.fromJson(Map<String, dynamic> json) {
    final off = json['offUntil'] as String?;
    return WorkerSummary(
      id: json['id'] as String,
      kind: json['kind'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      active: json['active'] as bool,
      scheduleConfigured: json['scheduleConfigured'] as bool,
      offUntil: off == null ? null : DateTime.parse(off),
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num? ?? 0).toInt(),
    );
  }
}

/// One working interval on one weekday (1 = Monday .. 7 = Sunday).
class HoursInterval {
  final int dayOfWeek;
  final TimeOfDay start;
  final TimeOfDay end;

  const HoursInterval({required this.dayOfWeek, required this.start, required this.end});

  factory HoursInterval.fromJson(Map<String, dynamic> json) => HoursInterval(
        dayOfWeek: (json['dayOfWeek'] as num).toInt(),
        start: _parseTime(json['startTime'] as String),
        end: _parseTime(json['endTime'] as String),
      );

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'startTime': formatTime(start),
        'endTime': formatTime(end),
      };

  static TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// "HH:mm:00", the backend's time format.
  static String formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
}

class WorkerScheduleData {
  final bool configured;
  final String? zoneId;
  final int slotMinutes;
  final int breakMinutes;
  final List<HoursInterval> hours;

  const WorkerScheduleData({
    required this.configured,
    required this.zoneId,
    required this.slotMinutes,
    required this.breakMinutes,
    required this.hours,
  });

  factory WorkerScheduleData.fromJson(Map<String, dynamic> json) => WorkerScheduleData(
        configured: json['configured'] as bool,
        zoneId: json['zoneId'] as String?,
        slotMinutes: (json['slotMinutes'] as num?)?.toInt() ?? 60,
        breakMinutes: (json['breakMinutes'] as num?)?.toInt() ?? 0,
        hours: (json['hours'] as List<dynamic>)
            .map((e) => HoursInterval.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SaveScheduleResult {
  final WorkerScheduleData schedule;
  final int slotsCreated;
  final int slotsRemoved;

  const SaveScheduleResult({required this.schedule, required this.slotsCreated, required this.slotsRemoved});

  factory SaveScheduleResult.fromJson(Map<String, dynamic> json) => SaveScheduleResult(
        schedule: WorkerScheduleData.fromJson(json['schedule'] as Map<String, dynamic>),
        slotsCreated: (json['slotsCreated'] as num).toInt(),
        slotsRemoved: (json['slotsRemoved'] as num).toInt(),
      );
}

class TimeOffItem {
  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? reason;

  /// True when the person themselves recorded it.
  final bool byWorker;

  const TimeOffItem({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.reason,
    required this.byWorker,
  });

  factory TimeOffItem.fromJson(Map<String, dynamic> json) => TimeOffItem(
        id: json['id'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        reason: json['reason'] as String?,
        byWorker: json['byWorker'] as bool,
      );
}

/// What recording time off did: the period, and how many already-booked appointments fall inside it.
class TimeOffCreated {
  final TimeOffItem timeOff;
  final int affectedAppointments;

  const TimeOffCreated({required this.timeOff, required this.affectedAppointments});

  factory TimeOffCreated.fromJson(Map<String, dynamic> json) => TimeOffCreated(
        timeOff: TimeOffItem.fromJson(json['timeOff'] as Map<String, dynamic>),
        affectedAppointments: (json['affectedAppointments'] as num).toInt(),
      );
}

class WorkforceSettings {
  final bool allowWorkerChoice;
  final bool workerPricingEnabled;

  const WorkforceSettings({required this.allowWorkerChoice, required this.workerPricingEnabled});

  factory WorkforceSettings.fromJson(Map<String, dynamic> json) => WorkforceSettings(
        allowWorkerChoice: json['allowWorkerChoice'] as bool,
        workerPricingEnabled: json['workerPricingEnabled'] as bool,
      );
}

/// One person's rating for the business owner — mirrors the backend's `WorkerPortalDtos.WorkerRatingResponse`.
class WorkerRating {
  /// Null until the first review (absent, not zero).
  final double? averageRating;
  final int reviewCount;

  /// Review counts for 1..5 stars, index 0 = one star.
  final List<int> distribution;
  final List<WorkerReviewItem> reviews;

  const WorkerRating({
    required this.averageRating,
    required this.reviewCount,
    required this.distribution,
    required this.reviews,
  });

  factory WorkerRating.fromJson(Map<String, dynamic> json) {
    return WorkerRating(
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num).toInt(),
      distribution: [for (final n in json['distribution'] as List<dynamic>) (n as num).toInt()],
      reviews: [
        for (final r in json['reviews'] as List<dynamic>) WorkerReviewItem.fromJson(r as Map<String, dynamic>),
      ],
    );
  }
}

class WorkerReviewItem {
  final String? customerName;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? businessReply;

  const WorkerReviewItem({
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.businessReply,
  });

  factory WorkerReviewItem.fromJson(Map<String, dynamic> json) {
    return WorkerReviewItem(
      customerName: json['customerName'] as String?,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      businessReply: json['businessReply'] as String?,
    );
  }
}
