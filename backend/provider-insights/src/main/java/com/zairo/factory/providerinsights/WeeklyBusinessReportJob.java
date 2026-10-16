package com.zairo.factory.providerinsights;

import java.time.Clock;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Monday morning (UTC): the previous seven days as an email to every active business owner. */
@Component
class WeeklyBusinessReportJob {

    private final WeeklyBusinessReportService reportService;
    private final Clock clock;

    WeeklyBusinessReportJob(WeeklyBusinessReportService reportService, Clock clock) {
        this.reportService = reportService;
        this.clock = clock;
    }

    @Scheduled(cron = "0 0 5 * * MON", zone = "UTC")
    void sendWeeklyReports() {
        reportService.publishReports(clock.instant());
    }
}
