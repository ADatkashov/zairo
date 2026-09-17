package com.zairo.factory.campaigncenter;

import com.zairo.factory.booking.AvailabilitySlot;
import com.zairo.factory.booking.AvailabilitySlotRepository;
import com.zairo.factory.booking.AvailabilityStatus;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignActionType;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignDto;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignFailureReason;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignListFilter;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignListResponse;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignNextAction;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignOutcome;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignStatsResponse;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignStatus;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignTimelineEvent;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignTimelineEventType;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.CampaignTimelineResponse;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.SmartActionItem;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.SmartActionPriority;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.SmartActionType;
import com.zairo.factory.campaigncenter.CampaignCenterDtos.SmartActionsResponse;
import com.zairo.factory.customerintelligence.CustomerProviderProfile;
import com.zairo.factory.customerintelligence.CustomerProviderProfileRepository;
import com.zairo.factory.customerintelligence.RetentionStatus;
import com.zairo.factory.reactivationengine.ReactivationCampaign;
import com.zairo.factory.reactivationengine.ReactivationCampaignRepository;
import com.zairo.factory.reactivationengine.ReactivationCampaignService;
import com.zairo.factory.reactivationengine.ReactivationCampaignStatus;
import com.zairo.factory.rebookengine.RebookCampaign;
import com.zairo.factory.rebookengine.RebookCampaignRepository;
import com.zairo.factory.rebookengine.RebookCampaignService;
import com.zairo.factory.rebookengine.RebookCampaignStatus;
import com.zairo.factory.revenueengine.ActionType;
import com.zairo.factory.revenueengine.DecisionTrigger;
import com.zairo.factory.revenueengine.RevenueOutcome;
import com.zairo.factory.revenueengine.RevenueOutcomeRepository;
import com.zairo.factory.services.ServiceOffering;
import com.zairo.factory.services.ServiceOfferingRepository;
import com.zairo.factory.smartfill.CandidateOffer;
import com.zairo.factory.smartfill.CandidateOfferRepository;
import com.zairo.factory.smartfill.CandidateOfferStatus;
import com.zairo.factory.smartfill.SmartFillCampaign;
import com.zairo.factory.smartfill.SmartFillCampaignRepository;
import com.zairo.factory.smartfill.SmartFillCampaignService;
import com.zairo.factory.smartfill.SmartFillCampaignStatus;
import com.zairo.factory.staff.Staff;
import com.zairo.factory.staff.StaffRepository;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/**
 * The Campaign Center's read composition and safe-action dispatch layer --
 * see this module's package-info for why this reads three separate engine
 * tables rather than owning a fourth.
 */
@Service
public class CampaignCenterService {

    private static final Duration EXPIRING_SOON_WINDOW = Duration.ofHours(2);
    private static final int DEFAULT_PAGE_SIZE = 20;
    private static final int MAX_PAGE_SIZE = 100;

    private final SmartFillCampaignRepository smartFillCampaignRepository;
    private final CandidateOfferRepository candidateOfferRepository;
    private final SmartFillCampaignService smartFillCampaignService;
    private final RebookCampaignRepository rebookCampaignRepository;
    private final RebookCampaignService rebookCampaignService;
    private final ReactivationCampaignRepository reactivationCampaignRepository;
    private final ReactivationCampaignService reactivationCampaignService;
    private final RevenueOutcomeRepository revenueOutcomeRepository;
    private final ServiceOfferingRepository serviceOfferingRepository;
    private final StaffRepository staffRepository;
    private final AvailabilitySlotRepository availabilitySlotRepository;
    private final CustomerProviderProfileRepository customerProviderProfileRepository;
    private final Clock clock;

    public CampaignCenterService(SmartFillCampaignRepository smartFillCampaignRepository,
            CandidateOfferRepository candidateOfferRepository, SmartFillCampaignService smartFillCampaignService,
            RebookCampaignRepository rebookCampaignRepository, RebookCampaignService rebookCampaignService,
            ReactivationCampaignRepository reactivationCampaignRepository,
            ReactivationCampaignService reactivationCampaignService, RevenueOutcomeRepository revenueOutcomeRepository,
            ServiceOfferingRepository serviceOfferingRepository, StaffRepository staffRepository,
            AvailabilitySlotRepository availabilitySlotRepository,
            CustomerProviderProfileRepository customerProviderProfileRepository, Clock clock) {
        this.smartFillCampaignRepository = smartFillCampaignRepository;
        this.candidateOfferRepository = candidateOfferRepository;
        this.smartFillCampaignService = smartFillCampaignService;
        this.rebookCampaignRepository = rebookCampaignRepository;
        this.rebookCampaignService = rebookCampaignService;
        this.reactivationCampaignRepository = reactivationCampaignRepository;
        this.reactivationCampaignService = reactivationCampaignService;
        this.revenueOutcomeRepository = revenueOutcomeRepository;
        this.serviceOfferingRepository = serviceOfferingRepository;
        this.staffRepository = staffRepository;
        this.availabilitySlotRepository = availabilitySlotRepository;
        this.customerProviderProfileRepository = customerProviderProfileRepository;
        this.clock = clock;
    }

    // ---------------------------------------------------------------- list

    public CampaignListResponse list(UUID providerId, CampaignListFilter filter) {
        List<CampaignDto> all = loadAllCampaigns(providerId, filter.from(), filter.to());

        Comparator<CampaignDto> order = Comparator.comparing(CampaignDto::createdAt);
        if (filter.newestFirst()) {
            order = order.reversed();
        }
        String search = filter.search() == null ? null : filter.search().trim().toLowerCase(Locale.ROOT);

        List<CampaignDto> filtered = all.stream()
                .filter(c -> filter.type() == null || c.type() == filter.type())
                .filter(c -> filter.status() == null || c.status() == filter.status())
                .filter(c -> filter.serviceId() == null || filter.serviceId().equals(c.serviceId()))
                .filter(c -> filter.employeeId() == null || filter.employeeId().equals(c.employeeId()))
                .filter(c -> search == null || search.isBlank() || matchesSearch(c, search))
                .sorted(order)
                .toList();

        int pageSize = filter.pageSize() <= 0 ? DEFAULT_PAGE_SIZE : Math.min(filter.pageSize(), MAX_PAGE_SIZE);
        int page = Math.max(filter.page(), 0);
        long totalItems = filtered.size();
        int totalPages = totalItems == 0 ? 0 : (int) Math.ceil((double) totalItems / pageSize);
        int fromIndex = Math.min(page * pageSize, filtered.size());
        int toIndex = Math.min(fromIndex + pageSize, filtered.size());

        return new CampaignListResponse(filtered.subList(fromIndex, toIndex), page, pageSize, totalItems, totalPages);
    }

    private static boolean matchesSearch(CampaignDto c, String search) {
        return (c.serviceTitle() != null && c.serviceTitle().toLowerCase(Locale.ROOT).contains(search))
                || (c.employeeName() != null && c.employeeName().toLowerCase(Locale.ROOT).contains(search));
    }

    // -------------------------------------------------------------- detail

    public CampaignDto detail(UUID providerId, CampaignType type, UUID campaignId) {
        CampaignDto dto = switch (type) {
            case SMART_FILL -> detailSmartFill(providerId, campaignId);
            case REBOOK -> detailRebook(providerId, campaignId);
            case REACTIVATION -> detailReactivation(providerId, campaignId);
        };
        if (dto == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Campaign not found: " + campaignId);
        }
        return dto;
    }

    private CampaignDto detailSmartFill(UUID providerId, UUID campaignId) {
        SmartFillCampaign campaign = smartFillCampaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || !campaign.getProviderId().equals(providerId)) {
            return null;
        }
        List<CandidateOffer> offers = candidateOfferRepository.findByCampaignId(campaignId);
        return toDto(campaign, offers, serviceTitles(List.of(campaign), List.of(), List.of()),
                employeeNames(List.of(campaign)), retryEligibleSlots(List.of(campaign)),
                revenueOutcomesByKey(providerId));
    }

    private CampaignDto detailRebook(UUID providerId, UUID campaignId) {
        RebookCampaign campaign = rebookCampaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || !campaign.getProviderId().equals(providerId)) {
            return null;
        }
        return toDto(campaign, serviceTitles(List.of(), List.of(campaign), List.of()), revenueOutcomesByKey(providerId));
    }

    private CampaignDto detailReactivation(UUID providerId, UUID campaignId) {
        ReactivationCampaign campaign = reactivationCampaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || !campaign.getProviderId().equals(providerId)) {
            return null;
        }
        return toDto(campaign, serviceTitles(List.of(), List.of(), List.of(campaign)), revenueOutcomesByKey(providerId));
    }

    // ------------------------------------------------------------ timeline

    public CampaignTimelineResponse timeline(UUID providerId, CampaignType type, UUID campaignId) {
        return switch (type) {
            case SMART_FILL -> smartFillTimeline(providerId, campaignId);
            case REBOOK -> rebookTimeline(providerId, campaignId);
            case REACTIVATION -> reactivationTimeline(providerId, campaignId);
        };
    }

    private CampaignTimelineResponse smartFillTimeline(UUID providerId, UUID campaignId) {
        SmartFillCampaign campaign = requireOwnedSmartFill(providerId, campaignId);
        List<CandidateOffer> offers = candidateOfferRepository.findByCampaignId(campaignId);

        List<CampaignTimelineEvent> events = new ArrayList<>();
        events.add(new CampaignTimelineEvent(CampaignTimelineEventType.CAMPAIGN_CREATED, campaign.getCreatedAt(), null));
        if (!offers.isEmpty()) {
            Instant selectedAt = offers.stream().map(CandidateOffer::getCreatedAt).min(Instant::compareTo)
                    .orElse(campaign.getCreatedAt());
            events.add(new CampaignTimelineEvent(CampaignTimelineEventType.CANDIDATES_SELECTED, selectedAt, null));
        }
        offers.stream().filter(o -> o.getNotifiedAt() != null)
                .sorted(Comparator.comparing(CandidateOffer::getNotifiedAt))
                .forEach(o -> events.add(new CampaignTimelineEvent(CampaignTimelineEventType.NOTIFICATION_SENT,
                        o.getNotifiedAt(), o.getUserId())));
        offers.stream()
                .filter(o -> o.getStatus() == CandidateOfferStatus.ACCEPTED && o.getRespondedAt() != null)
                .forEach(o -> {
                    events.add(new CampaignTimelineEvent(CampaignTimelineEventType.OFFER_ACCEPTED, o.getRespondedAt(),
                            o.getUserId()));
                    events.add(new CampaignTimelineEvent(CampaignTimelineEventType.BOOKING_CREATED, o.getRespondedAt(),
                            o.getUserId()));
                });
        if (campaign.getCompletedAt() != null) {
            CampaignTimelineEventType terminal = switch (campaign.getStatus()) {
                case BOOKED -> CampaignTimelineEventType.SLOT_RECOVERED;
                case CANCELLED -> CampaignTimelineEventType.CAMPAIGN_CANCELLED;
                default -> CampaignTimelineEventType.CAMPAIGN_EXPIRED;
            };
            events.add(new CampaignTimelineEvent(terminal, campaign.getCompletedAt(), null));
        }
        events.sort(Comparator.comparing(CampaignTimelineEvent::occurredAt));
        return new CampaignTimelineResponse(providerId, CampaignType.SMART_FILL, campaignId, events);
    }

    private CampaignTimelineResponse rebookTimeline(UUID providerId, UUID campaignId) {
        RebookCampaign campaign = rebookCampaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || !campaign.getProviderId().equals(providerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Campaign not found: " + campaignId);
        }
        // Rebook has no distinct "offer sent at" timestamp -- only its own
        // status records that a nudge went out (see this module's
        // package-info) -- so NOTIFICATION_SENT is never fabricated here.
        List<CampaignTimelineEvent> events = new ArrayList<>();
        events.add(new CampaignTimelineEvent(CampaignTimelineEventType.CAMPAIGN_CREATED, campaign.getCreatedAt(), null));
        if (campaign.getCompletedAt() != null) {
            CampaignTimelineEventType terminal = switch (campaign.getStatus()) {
                case BOOKED -> CampaignTimelineEventType.SLOT_RECOVERED;
                case CANCELLED -> CampaignTimelineEventType.CAMPAIGN_CANCELLED;
                default -> CampaignTimelineEventType.CAMPAIGN_EXPIRED;
            };
            events.add(new CampaignTimelineEvent(terminal, campaign.getCompletedAt(), null));
        }
        return new CampaignTimelineResponse(providerId, CampaignType.REBOOK, campaignId, events);
    }

    private CampaignTimelineResponse reactivationTimeline(UUID providerId, UUID campaignId) {
        ReactivationCampaign campaign = reactivationCampaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || !campaign.getProviderId().equals(providerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Campaign not found: " + campaignId);
        }
        List<CampaignTimelineEvent> events = new ArrayList<>();
        events.add(new CampaignTimelineEvent(CampaignTimelineEventType.CAMPAIGN_CREATED, campaign.getCreatedAt(), null));
        // Reactivation sends its win-back nudge immediately at creation
        // (see reactivationengine's own package-info) -- a real event, at a
        // real (if coincident) timestamp, unlike Rebook's above.
        events.add(new CampaignTimelineEvent(CampaignTimelineEventType.NOTIFICATION_SENT, campaign.getCreatedAt(),
                campaign.getUserId()));
        if (campaign.getCompletedAt() != null) {
            CampaignTimelineEventType terminal = switch (campaign.getStatus()) {
                case BOOKED -> CampaignTimelineEventType.SLOT_RECOVERED;
                case CANCELLED -> CampaignTimelineEventType.CAMPAIGN_CANCELLED;
                default -> CampaignTimelineEventType.CAMPAIGN_EXPIRED;
            };
            events.add(new CampaignTimelineEvent(terminal, campaign.getCompletedAt(), null));
        }
        return new CampaignTimelineResponse(providerId, CampaignType.REACTIVATION, campaignId, events);
    }

    // --------------------------------------------------------------- stats

    public CampaignStatsResponse stats(UUID providerId) {
        List<CampaignDto> all = loadAllCampaigns(providerId, null, null);

        long active = countByStatus(all, CampaignStatus.ACTIVE) + countByStatus(all, CampaignStatus.PAUSED);
        long completed = countByStatus(all, CampaignStatus.COMPLETED);
        long failed = countByStatus(all, CampaignStatus.FAILED);
        long expired = countByStatus(all, CampaignStatus.EXPIRED);
        long cancelled = countByStatus(all, CampaignStatus.CANCELLED);

        List<CampaignDto> recovered = all.stream().filter(c -> c.outcome() == CampaignOutcome.RECOVERED).toList();
        BigDecimal totalRecoveredRevenue = recovered.stream().map(CampaignDto::recoveredRevenue)
                .filter(Objects::nonNull).reduce(BigDecimal.ZERO, BigDecimal::add);
        String currency = recovered.stream().map(CampaignDto::currency).filter(Objects::nonNull).findFirst()
                .orElse(null);

        double conversionRate = all.isEmpty() ? 0.0 : (double) completed / all.size();
        long notificationsSent = all.stream().mapToLong(CampaignDto::notifiedCount).sum();
        long offersAccepted = all.stream().mapToLong(CampaignDto::acceptedCount).sum();

        List<Long> completionMinutes = all.stream().filter(c -> c.completedAt() != null)
                .map(c -> Duration.between(c.createdAt(), c.completedAt()).toMinutes()).toList();
        Double averageCompletionMinutes = completionMinutes.isEmpty() ? null
                : completionMinutes.stream().mapToLong(Long::longValue).average().orElse(0.0);

        long requiringAttention = smartActions(providerId).items().size();

        return new CampaignStatsResponse(providerId, active, completed, failed, expired, cancelled, completed,
                totalRecoveredRevenue, currency, conversionRate, notificationsSent, offersAccepted,
                averageCompletionMinutes, requiringAttention);
    }

    private static long countByStatus(List<CampaignDto> all, CampaignStatus status) {
        return all.stream().filter(c -> c.status() == status).count();
    }

    // --------------------------------------------------------- smart actions

    public SmartActionsResponse smartActions(UUID providerId) {
        Instant now = clock.instant();
        List<SmartActionItem> items = new ArrayList<>();

        List<SmartFillCampaign> smartFill = smartFillCampaignRepository.findByProviderId(providerId);
        Map<UUID, List<CandidateOffer>> offersByCampaignId = offersByCampaignId(smartFill);

        for (SmartFillCampaign campaign : smartFill) {
            if (campaign.getStatus() == SmartFillCampaignStatus.NOTIFYING && campaign.getSlotStartsAt() != null
                    && !campaign.getSlotStartsAt().isBefore(now)
                    && Duration.between(now, campaign.getSlotStartsAt()).compareTo(EXPIRING_SOON_WINDOW) <= 0) {
                items.add(new SmartActionItem(SmartActionType.CAMPAIGN_EXPIRING_SOON, SmartActionPriority.HIGH,
                        providerId, CampaignType.SMART_FILL, campaign.getId(), null, campaign.getServiceId(),
                        campaign.getEmployeeId(), null, campaign.getSlotStartsAt(), now, List.of()));
                continue;
            }
            if (campaign.getStatus() == SmartFillCampaignStatus.EXPIRED && campaign.getRecoveredBookingId() == null) {
                AvailabilitySlot slot = availabilitySlotRepository.findById(campaign.getAvailabilitySlotId())
                        .orElse(null);
                if (isSlotOpen(slot)) {
                    boolean everNotified = offersByCampaignId.getOrDefault(campaign.getId(), List.of()).stream()
                            .anyMatch(o -> o.getNotifiedAt() != null);
                    items.add(new SmartActionItem(
                            everNotified ? SmartActionType.RETRIABLE_CAMPAIGN : SmartActionType.FAILED_CAMPAIGN,
                            SmartActionPriority.MEDIUM, providerId, CampaignType.SMART_FILL, campaign.getId(), null,
                            campaign.getServiceId(), campaign.getEmployeeId(), null, campaign.getCompletedAt(), now,
                            List.of(CampaignActionType.RETRY)));
                }
            }
        }

        List<CustomerProviderProfile> profiles = customerProviderProfileRepository.findByProviderId(providerId);
        for (CustomerProviderProfile profile : profiles) {
            Instant relatedAt = profile.getNextExpectedVisitAt() != null ? profile.getNextExpectedVisitAt()
                    : profile.getLastVisitAt();
            if (profile.getRetentionStatus() == RetentionStatus.DUE_FOR_REBOOKING) {
                items.add(new SmartActionItem(SmartActionType.REBOOKING_OPPORTUNITY, SmartActionPriority.MEDIUM,
                        providerId, null, null, profile.getUserId(), profile.getFavouriteServiceId(), null, null,
                        relatedAt, now, List.of()));
            } else if (profile.getRetentionStatus() == RetentionStatus.AT_RISK) {
                items.add(new SmartActionItem(SmartActionType.AT_RISK_CUSTOMER, SmartActionPriority.HIGH, providerId,
                        null, null, profile.getUserId(), profile.getFavouriteServiceId(), null, null,
                        profile.getLastVisitAt(), now, List.of()));
            } else if (profile.getRetentionStatus() == RetentionStatus.INACTIVE) {
                items.add(new SmartActionItem(SmartActionType.LONG_INACTIVE_CUSTOMER, SmartActionPriority.LOW,
                        providerId, null, null, profile.getUserId(), profile.getFavouriteServiceId(), null, null,
                        profile.getLastVisitAt(), now, List.of()));
            }
        }

        items.sort(Comparator.comparing(SmartActionItem::priority));
        return new SmartActionsResponse(providerId, items);
    }

    // -------------------------------------------------------------- actions

    /** Throws 404 (unowned/missing) or 409 (not in a state where this action applies) -- never silently no-ops on the controller side. */
    public void executeAction(UUID providerId, CampaignType type, UUID campaignId, CampaignActionType action) {
        boolean applied = switch (type) {
            case SMART_FILL -> executeSmartFillAction(providerId, campaignId, action);
            case REBOOK -> executeRebookAction(providerId, campaignId, action);
            case REACTIVATION -> executeReactivationAction(providerId, campaignId, action);
        };
        if (!applied) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    action + " cannot be applied to this campaign right now");
        }
    }

    private boolean executeSmartFillAction(UUID providerId, UUID campaignId, CampaignActionType action) {
        requireOwnedSmartFill(providerId, campaignId);
        Instant now = clock.instant();
        return switch (action) {
            case PAUSE -> smartFillCampaignService.pauseCampaign(campaignId);
            case RESUME -> smartFillCampaignService.resumeCampaign(campaignId, now);
            case CANCEL -> smartFillCampaignService.cancelCampaign(campaignId, now);
            case RETRY -> smartFillCampaignService.retryCampaign(campaignId, now);
        };
    }

    private boolean executeRebookAction(UUID providerId, UUID campaignId, CampaignActionType action) {
        RebookCampaign campaign = rebookCampaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || !campaign.getProviderId().equals(providerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Campaign not found: " + campaignId);
        }
        if (action != CampaignActionType.CANCEL) {
            return false;
        }
        return rebookCampaignService.cancelCampaign(campaignId, clock.instant());
    }

    private boolean executeReactivationAction(UUID providerId, UUID campaignId, CampaignActionType action) {
        ReactivationCampaign campaign = reactivationCampaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || !campaign.getProviderId().equals(providerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Campaign not found: " + campaignId);
        }
        if (action != CampaignActionType.CANCEL) {
            return false;
        }
        return reactivationCampaignService.cancelCampaign(campaignId, clock.instant());
    }

    private SmartFillCampaign requireOwnedSmartFill(UUID providerId, UUID campaignId) {
        SmartFillCampaign campaign = smartFillCampaignRepository.findById(campaignId).orElse(null);
        if (campaign == null || !campaign.getProviderId().equals(providerId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Campaign not found: " + campaignId);
        }
        return campaign;
    }

    // ------------------------------------------------------------ loading

    private List<CampaignDto> loadAllCampaigns(UUID providerId, Instant from, Instant to) {
        List<SmartFillCampaign> smartFill = from != null && to != null
                ? smartFillCampaignRepository.findByProviderIdAndCreatedAtBetween(providerId, from, to)
                : smartFillCampaignRepository.findByProviderId(providerId);
        List<RebookCampaign> rebook = from != null && to != null
                ? rebookCampaignRepository.findByProviderIdAndCreatedAtBetween(providerId, from, to)
                : rebookCampaignRepository.findByProviderId(providerId);
        List<ReactivationCampaign> reactivation = from != null && to != null
                ? reactivationCampaignRepository.findByProviderIdAndCreatedAtBetween(providerId, from, to)
                : reactivationCampaignRepository.findByProviderId(providerId);

        Map<UUID, List<CandidateOffer>> offersByCampaignId = offersByCampaignId(smartFill);
        Map<UUID, String> serviceTitles = serviceTitles(smartFill, rebook, reactivation);
        Map<UUID, String> employeeNames = employeeNames(smartFill);
        Map<UUID, AvailabilitySlot> retrySlots = retryEligibleSlots(smartFill);
        Map<String, RevenueOutcome> revenueByKey = revenueOutcomesByKey(providerId);

        List<CampaignDto> result = new ArrayList<>(smartFill.size() + rebook.size() + reactivation.size());
        for (SmartFillCampaign campaign : smartFill) {
            result.add(toDto(campaign, offersByCampaignId.getOrDefault(campaign.getId(), List.of()), serviceTitles,
                    employeeNames, retrySlots, revenueByKey));
        }
        for (RebookCampaign campaign : rebook) {
            result.add(toDto(campaign, serviceTitles, revenueByKey));
        }
        for (ReactivationCampaign campaign : reactivation) {
            result.add(toDto(campaign, serviceTitles, revenueByKey));
        }
        return result;
    }

    private Map<UUID, List<CandidateOffer>> offersByCampaignId(List<SmartFillCampaign> campaigns) {
        if (campaigns.isEmpty()) {
            return Map.of();
        }
        List<UUID> ids = campaigns.stream().map(SmartFillCampaign::getId).toList();
        return candidateOfferRepository.findByCampaignIdIn(ids).stream()
                .collect(Collectors.groupingBy(CandidateOffer::getCampaignId));
    }

    private Map<UUID, String> serviceTitles(List<SmartFillCampaign> smartFill, List<RebookCampaign> rebook,
            List<ReactivationCampaign> reactivation) {
        Set<UUID> ids = new HashSet<>();
        smartFill.forEach(c -> ids.add(c.getServiceId()));
        rebook.forEach(c -> ids.add(c.getServiceId()));
        reactivation.forEach(c -> ids.add(c.getServiceId()));
        if (ids.isEmpty()) {
            return Map.of();
        }
        return serviceOfferingRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(ServiceOffering::getId, ServiceOffering::getTitle));
    }

    private Map<UUID, String> employeeNames(List<SmartFillCampaign> smartFill) {
        Set<UUID> ids = smartFill.stream().map(SmartFillCampaign::getEmployeeId).filter(Objects::nonNull)
                .collect(Collectors.toSet());
        if (ids.isEmpty()) {
            return Map.of();
        }
        return staffRepository.findAllById(ids).stream().collect(Collectors.toMap(Staff::getId, Staff::getDisplayName));
    }

    /** Only for EXPIRED, never-recovered campaigns -- exactly the ones {@link CampaignActionType#RETRY} might apply to. */
    private Map<UUID, AvailabilitySlot> retryEligibleSlots(List<SmartFillCampaign> smartFill) {
        List<UUID> slotIds = smartFill.stream()
                .filter(c -> c.getStatus() == SmartFillCampaignStatus.EXPIRED && c.getRecoveredBookingId() == null)
                .map(SmartFillCampaign::getAvailabilitySlotId).toList();
        if (slotIds.isEmpty()) {
            return Map.of();
        }
        return availabilitySlotRepository.findAllById(slotIds).stream()
                .collect(Collectors.toMap(AvailabilitySlot::getId, s -> s));
    }

    /** One query for the whole provider (see {@code RevenueOutcomeRepository#findByProviderId}), keyed in memory -- never one lookup per campaign. */
    private Map<String, RevenueOutcome> revenueOutcomesByKey(UUID providerId) {
        return revenueOutcomeRepository.findByProviderId(providerId).stream()
                .collect(Collectors.toMap(o -> revenueOutcomeKey(o.getActionType(), o.getTriggerRefId()), o -> o,
                        (a, b) -> a));
    }

    private static String revenueOutcomeKey(ActionType actionType, UUID triggerRefId) {
        return actionType.name() + ":" + triggerRefId;
    }

    private static boolean isSlotOpen(AvailabilitySlot slot) {
        return slot != null && slot.getStatus() == AvailabilityStatus.OPEN;
    }

    // -------------------------------------------------------------- mapping

    private CampaignDto toDto(SmartFillCampaign campaign, List<CandidateOffer> offers, Map<UUID, String> serviceTitles,
            Map<UUID, String> employeeNames, Map<UUID, AvailabilitySlot> retrySlots, Map<String, RevenueOutcome> revenueByKey) {
        int notified = (int) offers.stream().filter(o -> o.getNotifiedAt() != null).count();
        int viewed = (int) offers.stream()
                .filter(o -> o.getStatus() == CandidateOfferStatus.VIEWED || o.getStatus() == CandidateOfferStatus.ACCEPTED)
                .count();
        int accepted = (int) offers.stream().filter(o -> o.getStatus() == CandidateOfferStatus.ACCEPTED).count();
        UUID customerId = offers.stream().filter(o -> o.getStatus() == CandidateOfferStatus.ACCEPTED)
                .map(CandidateOffer::getUserId).findFirst().orElse(null);

        CampaignStatus status = mapSmartFillStatus(campaign.getStatus(), notified);
        RevenueOutcome outcome = revenueByKey.get(revenueOutcomeKey(ActionType.SMART_FILL, campaign.getCancelledBookingId()));
        Instant updatedAt = latestOf(campaign.getCreatedAt(), campaign.getCompletedAt(),
                offers.stream().map(CandidateOffer::getNotifiedAt).filter(Objects::nonNull).max(Instant::compareTo).orElse(null),
                offers.stream().map(CandidateOffer::getRespondedAt).filter(Objects::nonNull).max(Instant::compareTo).orElse(null));
        CampaignFailureReason failureReason = status == CampaignStatus.FAILED
                ? CampaignFailureReason.NO_CANDIDATES_NOTIFIED : null;

        SmartFillCampaignStatus raw = campaign.getStatus();
        boolean activeOrPaused = raw == SmartFillCampaignStatus.CREATED || raw == SmartFillCampaignStatus.SEARCHING
                || raw == SmartFillCampaignStatus.NOTIFYING || raw == SmartFillCampaignStatus.PAUSED;
        boolean retryEligible = raw == SmartFillCampaignStatus.EXPIRED && campaign.getRecoveredBookingId() == null
                && isSlotOpen(retrySlots.get(campaign.getAvailabilitySlotId()));

        List<CampaignActionType> actions = new ArrayList<>();
        if (raw == SmartFillCampaignStatus.NOTIFYING) {
            actions.add(CampaignActionType.PAUSE);
        }
        if (raw == SmartFillCampaignStatus.PAUSED) {
            actions.add(CampaignActionType.RESUME);
        }
        if (activeOrPaused) {
            actions.add(CampaignActionType.CANCEL);
        }
        if (retryEligible) {
            actions.add(CampaignActionType.RETRY);
        }

        CampaignNextAction nextAction = nextActionFor(status, actions, campaign.getRecoveredBookingId() != null);

        return new CampaignDto(campaign.getId(), CampaignType.SMART_FILL, status, raw.name(),
                DecisionTrigger.BOOKING_CANCELLED, campaign.getProviderId(), campaign.getServiceId(),
                serviceTitles.get(campaign.getServiceId()), campaign.getEmployeeId(),
                campaign.getEmployeeId() == null ? null : employeeNames.get(campaign.getEmployeeId()), customerId,
                campaign.getSlotStartsAt(), campaign.getSlotEndsAt(), offers.size(), notified, viewed, accepted,
                campaign.getRecoveredBookingId(), outcome == null ? null : outcome.getActualRevenue(),
                outcome == null ? campaign.getPriceCurrency() : outcome.getCurrency(), campaign.getCreatedAt(),
                updatedAt, campaign.getCompletedAt(), outcomeOf(outcome), failureReason, nextAction, actions);
    }

    private CampaignDto toDto(RebookCampaign campaign, Map<UUID, String> serviceTitles, Map<String, RevenueOutcome> revenueByKey) {
        CampaignStatus status = switch (campaign.getStatus()) {
            case CREATED, OFFERED -> CampaignStatus.ACTIVE;
            case BOOKED -> CampaignStatus.COMPLETED;
            case EXPIRED -> CampaignStatus.EXPIRED;
            case CANCELLED -> CampaignStatus.CANCELLED;
        };
        RevenueOutcome outcome = revenueByKey.get(revenueOutcomeKey(ActionType.REBOOK, campaign.getCompletedBookingId()));
        boolean active = campaign.getStatus() == RebookCampaignStatus.CREATED
                || campaign.getStatus() == RebookCampaignStatus.OFFERED;
        // A nudge was definitely sent once OFFERED/BOOKED/EXPIRED; CANCELLED
        // could have happened either before or after the nudge went out and
        // Rebook doesn't persist which -- undercounting CANCELLED as
        // "not notified" is the documented, honest choice (see this
        // module's package-info) rather than guessing.
        int notified = campaign.getStatus() == RebookCampaignStatus.OFFERED
                || campaign.getStatus() == RebookCampaignStatus.BOOKED
                || campaign.getStatus() == RebookCampaignStatus.EXPIRED ? 1 : 0;
        int accepted = campaign.getRecoveredBookingId() != null ? 1 : 0;

        List<CampaignActionType> actions = active ? List.of(CampaignActionType.CANCEL) : List.of();
        CampaignNextAction nextAction = campaign.getRecoveredBookingId() != null ? CampaignNextAction.VIEW_RECOVERED_BOOKING
                : active ? CampaignNextAction.WAITING_FOR_RESPONSE : CampaignNextAction.NONE;
        Instant updatedAt = campaign.getCompletedAt() != null ? campaign.getCompletedAt() : campaign.getCreatedAt();

        return new CampaignDto(campaign.getId(), CampaignType.REBOOK, status, campaign.getStatus().name(),
                DecisionTrigger.BOOKING_COMPLETED, campaign.getProviderId(), campaign.getServiceId(),
                serviceTitles.get(campaign.getServiceId()), null, null, campaign.getUserId(), null, null, 1, notified,
                0, accepted, campaign.getRecoveredBookingId(), outcome == null ? null : outcome.getActualRevenue(),
                outcome == null ? campaign.getPriceCurrency() : outcome.getCurrency(), campaign.getCreatedAt(),
                updatedAt, campaign.getCompletedAt(), outcomeOf(outcome), null, nextAction, actions);
    }

    private CampaignDto toDto(ReactivationCampaign campaign, Map<UUID, String> serviceTitles, Map<String, RevenueOutcome> revenueByKey) {
        CampaignStatus status = switch (campaign.getStatus()) {
            case SENT -> CampaignStatus.ACTIVE;
            case BOOKED -> CampaignStatus.COMPLETED;
            case EXPIRED -> CampaignStatus.EXPIRED;
            case CANCELLED -> CampaignStatus.CANCELLED;
        };
        RevenueOutcome outcome = revenueByKey
                .get(revenueOutcomeKey(ActionType.CUSTOMER_REACTIVATION, campaign.getLastVisitBookingId()));
        boolean active = campaign.getStatus() == ReactivationCampaignStatus.SENT;
        int accepted = campaign.getRecoveredBookingId() != null ? 1 : 0;

        List<CampaignActionType> actions = active ? List.of(CampaignActionType.CANCEL) : List.of();
        CampaignNextAction nextAction = campaign.getRecoveredBookingId() != null ? CampaignNextAction.VIEW_RECOVERED_BOOKING
                : active ? CampaignNextAction.WAITING_FOR_RESPONSE : CampaignNextAction.NONE;
        Instant updatedAt = campaign.getCompletedAt() != null ? campaign.getCompletedAt() : campaign.getCreatedAt();

        return new CampaignDto(campaign.getId(), CampaignType.REACTIVATION, status, campaign.getStatus().name(),
                DecisionTrigger.CUSTOMER_INACTIVE, campaign.getProviderId(), campaign.getServiceId(),
                serviceTitles.get(campaign.getServiceId()), null, null, campaign.getUserId(), null, null, 1, 1, 0,
                accepted, campaign.getRecoveredBookingId(), outcome == null ? null : outcome.getActualRevenue(),
                outcome == null ? campaign.getPriceCurrency() : outcome.getCurrency(), campaign.getCreatedAt(),
                updatedAt, campaign.getCompletedAt(), outcomeOf(outcome), null, nextAction, actions);
    }

    private static CampaignStatus mapSmartFillStatus(SmartFillCampaignStatus raw, int notifiedCount) {
        return switch (raw) {
            case CREATED, SEARCHING, NOTIFYING -> CampaignStatus.ACTIVE;
            case PAUSED -> CampaignStatus.PAUSED;
            case BOOKED -> CampaignStatus.COMPLETED;
            case CANCELLED -> CampaignStatus.CANCELLED;
            case EXPIRED -> notifiedCount == 0 ? CampaignStatus.FAILED : CampaignStatus.EXPIRED;
        };
    }

    private static CampaignOutcome outcomeOf(RevenueOutcome outcome) {
        if (outcome == null || outcome.getRecovered() == null) {
            return CampaignOutcome.PENDING;
        }
        return Boolean.TRUE.equals(outcome.getRecovered()) ? CampaignOutcome.RECOVERED : CampaignOutcome.NOT_RECOVERED;
    }

    private static CampaignNextAction nextActionFor(CampaignStatus status, List<CampaignActionType> actions,
            boolean hasRecoveredBooking) {
        if (hasRecoveredBooking) {
            return CampaignNextAction.VIEW_RECOVERED_BOOKING;
        }
        if (status == CampaignStatus.PAUSED) {
            return CampaignNextAction.PAUSED_BY_OWNER;
        }
        if (actions.contains(CampaignActionType.RETRY)) {
            return CampaignNextAction.RETRY_AVAILABLE;
        }
        if (status == CampaignStatus.ACTIVE) {
            return CampaignNextAction.WAITING_FOR_RESPONSE;
        }
        return CampaignNextAction.NONE;
    }

    private static Instant latestOf(Instant... instants) {
        Instant latest = null;
        for (Instant instant : instants) {
            if (instant != null && (latest == null || instant.isAfter(latest))) {
                latest = instant;
            }
        }
        return latest;
    }
}
