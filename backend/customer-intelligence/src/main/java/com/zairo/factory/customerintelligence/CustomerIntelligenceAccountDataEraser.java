package com.zairo.factory.customerintelligence;

import com.zairo.factory.auth.AccountDataEraser;
import java.util.UUID;
import org.springframework.stereotype.Component;

/** The behaviour profiles computed about a customer are derived personal data -- gone with the account. */
@Component
class CustomerIntelligenceAccountDataEraser implements AccountDataEraser {

    private final CustomerProfileRepository profileRepository;
    private final CustomerProviderProfileRepository providerProfileRepository;
    private final CustomerEmployeeProfileRepository employeeProfileRepository;

    CustomerIntelligenceAccountDataEraser(CustomerProfileRepository profileRepository,
            CustomerProviderProfileRepository providerProfileRepository,
            CustomerEmployeeProfileRepository employeeProfileRepository) {
        this.profileRepository = profileRepository;
        this.providerProfileRepository = providerProfileRepository;
        this.employeeProfileRepository = employeeProfileRepository;
    }

    @Override
    public void eraseDataOf(UUID userId) {
        profileRepository.deleteByUserId(userId);
        providerProfileRepository.deleteByUserId(userId);
        employeeProfileRepository.deleteByUserId(userId);
    }
}
