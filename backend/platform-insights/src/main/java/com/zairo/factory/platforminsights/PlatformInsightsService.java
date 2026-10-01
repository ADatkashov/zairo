package com.zairo.factory.platforminsights;

import com.zairo.factory.booking.BookingRepository;
import com.zairo.factory.booking.BookingStatus;
import com.zairo.factory.payments.PaymentAllocation;
import com.zairo.factory.payments.PaymentAllocationRepository;
import com.zairo.factory.payments.PaymentRepository;
import com.zairo.factory.payments.PaymentStatus;
import com.zairo.factory.platforminsights.PlatformInsightsDtos.PlatformDashboardMetrics;
import com.zairo.factory.platforminsights.PlatformInsightsDtos.PlatformDashboardMetrics.BookingsSection;
import com.zairo.factory.platforminsights.PlatformInsightsDtos.PlatformDashboardMetrics.BusinessesSection;
import com.zairo.factory.platforminsights.PlatformInsightsDtos.PlatformDashboardMetrics.PaymentsSection;
import com.zairo.factory.platforminsights.PlatformInsightsDtos.PlatformDashboardMetrics.RevenueSection;
import com.zairo.factory.platforminsights.PlatformInsightsDtos.PlatformDashboardMetrics.SubscriptionsSection;
import com.zairo.factory.platforminsights.PlatformInsightsDtos.PlatformDashboardMetrics.UsersSection;
import com.zairo.factory.providers.ProviderRepository;
import com.zairo.factory.providers.ProviderStatus;
import com.zairo.factory.subscriptions.SubscriptionChargeRepository;
import com.zairo.factory.subscriptions.SubscriptionChargeStatus;
import com.zairo.factory.subscriptions.SubscriptionPlan;
import com.zairo.factory.subscriptions.SubscriptionRepository;
import com.zairo.factory.subscriptions.SubscriptionStatus;
import com.zairo.factory.users.UserRepository;
import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneOffset;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import org.springframework.stereotype.Service;

/**
 * Every number below is a live query (COUNT/SUM), nothing stored or
 * cached — fine at pilot scale (see package-info), worth revisiting only
 * once real volume makes it slow, not before.
 */
@Service
public class PlatformInsightsService {

    private final UserRepository userRepository;
    private final ProviderRepository providerRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final SubscriptionChargeRepository subscriptionChargeRepository;
    private final BookingRepository bookingRepository;
    private final PaymentRepository paymentRepository;
    private final PaymentAllocationRepository paymentAllocationRepository;

    public PlatformInsightsService(UserRepository userRepository, ProviderRepository providerRepository,
            SubscriptionRepository subscriptionRepository, SubscriptionChargeRepository subscriptionChargeRepository,
            BookingRepository bookingRepository, PaymentRepository paymentRepository,
            PaymentAllocationRepository paymentAllocationRepository) {
        this.userRepository = userRepository;
        this.providerRepository = providerRepository;
        this.subscriptionRepository = subscriptionRepository;
        this.subscriptionChargeRepository = subscriptionChargeRepository;
        this.bookingRepository = bookingRepository;
        this.paymentRepository = paymentRepository;
        this.paymentAllocationRepository = paymentAllocationRepository;
    }

    public PlatformDashboardMetrics dashboardMetrics() {
        Instant now = Instant.now();
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        Instant startOfToday = today.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant startOfWeek = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
                .atStartOfDay(ZoneOffset.UTC).toInstant();
        YearMonth thisMonth = YearMonth.now(ZoneOffset.UTC);
        Instant startOfMonth = thisMonth.atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant startOfNextMonth = thisMonth.plusMonths(1).atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant();

        UsersSection users = new UsersSection(userRepository.count());

        BusinessesSection businesses = new BusinessesSection(providerRepository.count(),
                providerRepository.countByStatus(ProviderStatus.ACTIVE),
                providerRepository.countByStatus(ProviderStatus.PENDING),
                providerRepository.countByStatus(ProviderStatus.SUSPENDED));

        SubscriptionsSection subscriptions = new SubscriptionsSection(
                subscriptionRepository.countByPlan(SubscriptionPlan.FREE),
                subscriptionRepository.countByPlan(SubscriptionPlan.PRO),
                subscriptionRepository.countByStatus(SubscriptionStatus.ACTIVE),
                subscriptionRepository.countByStatus(SubscriptionStatus.PAST_DUE),
                subscriptionRepository.countByStatus(SubscriptionStatus.CANCELLED));

        BookingsSection bookings = new BookingsSection(bookingRepository.countByCreatedAtBetween(startOfToday, now),
                bookingRepository.countByCreatedAtBetween(startOfWeek, now),
                bookingRepository.countByCreatedAtBetween(startOfMonth, now),
                bookingRepository.countByStatus(BookingStatus.COMPLETED),
                bookingRepository.countByStatus(BookingStatus.CANCELLED));

        PaymentsSection payments = new PaymentsSection(paymentRepository.countByStatus(PaymentStatus.SUCCEEDED),
                paymentRepository.countByStatus(PaymentStatus.FAILED),
                paymentRepository.countByStatus(PaymentStatus.PENDING),
                paymentRepository.countByStatus(PaymentStatus.REFUNDED),
                paymentRepository.countByStatus(PaymentStatus.REFUND_FAILED));

        var chargesThisMonth = subscriptionChargeRepository.findByStatusAndCreatedAtBetween(
                SubscriptionChargeStatus.SUCCEEDED, startOfMonth, startOfNextMonth);
        BigDecimal mrr = chargesThisMonth.stream().map(charge -> charge.getAmount())
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        String currency = chargesThisMonth.isEmpty() ? null : chargesThisMonth.get(0).getCurrency();

        List<PaymentAllocation> allocationsThisMonth = paymentAllocationRepository.findByCreatedAtBetween(
                startOfMonth, startOfNextMonth);
        BigDecimal platformCommission = allocationsThisMonth.stream().map(PaymentAllocation::getPlatformFee)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        String platformCommissionCurrency = allocationsThisMonth.isEmpty() ? null
                : allocationsThisMonth.get(0).getCurrency();

        RevenueSection revenue = new RevenueSection(mrr, currency, platformCommission, platformCommissionCurrency);

        return new PlatformDashboardMetrics(users, businesses, subscriptions, bookings, payments, revenue);
    }
}
