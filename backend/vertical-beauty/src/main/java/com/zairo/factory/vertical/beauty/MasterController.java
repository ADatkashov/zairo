package com.zairo.factory.vertical.beauty;

import com.zairo.factory.auth.CurrentUser;
import com.zairo.factory.vertical.beauty.MasterDtos.AddPortfolioItemRequest;
import com.zairo.factory.vertical.beauty.MasterDtos.CreateMasterRequest;
import com.zairo.factory.vertical.beauty.MasterDtos.MasterResponse;
import com.zairo.factory.vertical.beauty.MasterDtos.MasterServiceResponse;
import com.zairo.factory.vertical.beauty.MasterDtos.PortfolioItemResponse;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class MasterController {

    private final MasterDirectoryService masterDirectoryService;

    public MasterController(MasterDirectoryService masterDirectoryService) {
        this.masterDirectoryService = masterDirectoryService;
    }

    @PostMapping("/api/v1/beauty/providers/{providerId}/masters")
    @ResponseStatus(HttpStatus.CREATED)
    public MasterResponse create(@PathVariable UUID providerId, @RequestBody CreateMasterRequest request) {
        Master master = masterDirectoryService.createMaster(providerId, request.displayName(), request.bio(),
                request.photoUrl());
        return MasterResponse.from(master);
    }

    @GetMapping("/api/v1/beauty/providers/{providerId}/masters")
    public List<MasterResponse> listByProvider(@PathVariable UUID providerId) {
        return masterDirectoryService.listMastersByProvider(providerId).stream().map(MasterResponse::from).toList();
    }

    @GetMapping("/api/v1/beauty/masters/{masterId}")
    public MasterResponse getById(@PathVariable UUID masterId) {
        return MasterResponse.from(masterDirectoryService.getMaster(masterId));
    }

    /** Soft-delete — see Master.deactivate(). Idempotent. Owner-only. */
    @DeleteMapping("/api/v1/beauty/masters/{masterId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deactivate(@PathVariable UUID masterId, HttpServletRequest httpRequest) {
        masterDirectoryService.deactivateMaster(masterId, CurrentUser.requireUserId(httpRequest));
    }

    /** Owner-only. */
    @PostMapping("/api/v1/beauty/masters/{masterId}/portfolio")
    @ResponseStatus(HttpStatus.CREATED)
    public PortfolioItemResponse addPortfolioItem(@PathVariable UUID masterId,
            @RequestBody AddPortfolioItemRequest request, HttpServletRequest httpRequest) {
        return PortfolioItemResponse.from(masterDirectoryService.addPortfolioItem(masterId, request.imageUrl(),
                request.caption(), CurrentUser.requireUserId(httpRequest)));
    }

    @GetMapping("/api/v1/beauty/masters/{masterId}/portfolio")
    public List<PortfolioItemResponse> listPortfolio(@PathVariable UUID masterId) {
        return masterDirectoryService.listPortfolio(masterId).stream().map(PortfolioItemResponse::from).toList();
    }

    /** Owner-only. */
    @PostMapping("/api/v1/beauty/masters/{masterId}/services/{serviceId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void linkService(@PathVariable UUID masterId, @PathVariable UUID serviceId,
            HttpServletRequest httpRequest) {
        masterDirectoryService.linkService(masterId, serviceId, CurrentUser.requireUserId(httpRequest));
    }

    /** Owner-only. */
    @DeleteMapping("/api/v1/beauty/masters/{masterId}/services/{serviceId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unlinkService(@PathVariable UUID masterId, @PathVariable UUID serviceId,
            HttpServletRequest httpRequest) {
        masterDirectoryService.unlinkService(masterId, serviceId, CurrentUser.requireUserId(httpRequest));
    }

    @GetMapping("/api/v1/beauty/masters/{masterId}/services")
    public List<MasterServiceResponse> listServices(@PathVariable UUID masterId) {
        return masterDirectoryService.listServices(masterId).stream().map(MasterServiceResponse::from).toList();
    }
}
