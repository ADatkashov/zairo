package com.zairo.factory.ads;

import com.zairo.factory.ads.AdDtos.BannerResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/ads")
@Tag(name = "Ads")
public class AdController {

    private final AdService adService;

    public AdController(AdService adService) {
        this.adService = adService;
    }

    @Operation(summary = "Home-screen banners", description = "Banners that are live right now, in carousel order: "
            + "those for the given city plus those meant for every city (or only the latter without a city). "
            + "Public — a guest sees the same carousel. At most 10.")
    @ApiResponse(responseCode = "200", description = "Live banners, possibly empty")
    @GetMapping("/banners")
    public List<BannerResponse> banners(
            @Parameter(description = "City code (e.g. 'almaty'); omit for every-city banners only")
            @RequestParam(required = false) String city) {
        return adService.liveBanners(city);
    }
}
