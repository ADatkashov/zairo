import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

import '../campaign_center_exception.dart';
import '../models/campaign.dart';

/// Wraps the Campaign Center + Smart Actions REST surface
/// (backend/campaign-center/...) from the owner's point of view -- every
/// endpoint is owner-only, scoped under a provider the caller owns. Not
/// final: tests substitute a subclass, same pattern as [SalonAdminApi].
class CampaignCenterApi {
  final DioClient _dioClient;

  CampaignCenterApi(this._dioClient);

  Future<CampaignListResponse> fetchCampaigns(
    String providerId, {
    CampaignType? type,
    CampaignStatus? status,
    String? serviceId,
    String? employeeId,
    DateTime? from,
    DateTime? to,
    String? search,
    int page = 0,
    int pageSize = 20,
    bool newestFirst = true,
  }) async {
    final response = await _dioClient.get(
      '/providers/$providerId/campaigns',
      queryParameters: {
        if (type != null) 'type': type.toWire(),
        if (status != null) 'status': status.toWire(),
        'serviceId': ?serviceId,
        'employeeId': ?employeeId,
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
        'pageSize': pageSize,
        'newestFirst': newestFirst,
      },
    );
    return CampaignListResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CampaignStatsResponse> fetchStats(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/campaigns/stats');
    return CampaignStatsResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SmartActionsResponse> fetchSmartActions(String providerId) async {
    final response = await _dioClient.get('/providers/$providerId/smart-actions');
    return SmartActionsResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CampaignDto> fetchCampaignDetail(String providerId, CampaignType type, String campaignId) async {
    final response = await _dioClient.get('/providers/$providerId/campaigns/${type.toWire()}/$campaignId');
    return CampaignDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CampaignTimelineResponse> fetchTimeline(String providerId, CampaignType type, String campaignId) async {
    final response =
        await _dioClient.get('/providers/$providerId/campaigns/${type.toWire()}/$campaignId/timeline');
    return CampaignTimelineResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CampaignDto> pauseCampaign(String providerId, CampaignType type, String campaignId) {
    return _postAction(providerId, type, campaignId, 'pause');
  }

  Future<CampaignDto> resumeCampaign(String providerId, CampaignType type, String campaignId) {
    return _postAction(providerId, type, campaignId, 'resume');
  }

  Future<CampaignDto> cancelCampaign(String providerId, CampaignType type, String campaignId) {
    return _postAction(providerId, type, campaignId, 'cancel');
  }

  Future<CampaignDto> retryCampaign(String providerId, CampaignType type, String campaignId) {
    return _postAction(providerId, type, campaignId, 'retry');
  }

  /// A 409 means the action no longer applies (e.g. someone else already
  /// cancelled it, or a stale UI state) -- surfaced as
  /// [CampaignActionConflictException] so callers show a friendly notice
  /// and refresh instead of a crash.
  Future<CampaignDto> _postAction(String providerId, CampaignType type, String campaignId, String action) async {
    try {
      final response = await _dioClient.post('/providers/$providerId/campaigns/${type.toWire()}/$campaignId/$action');
      return CampaignDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const CampaignActionConflictException();
      }
      rethrow;
    }
  }
}
