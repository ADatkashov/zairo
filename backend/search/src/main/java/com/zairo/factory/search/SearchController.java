package com.zairo.factory.search;

import com.zairo.factory.search.SearchDtos.ProviderSearchResult;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class SearchController {

    private final SearchService searchService;

    public SearchController(SearchService searchService) {
        this.searchService = searchService;
    }

    @GetMapping("/api/v1/search/providers")
    public List<ProviderSearchResult> search(@RequestParam(required = false) String vertical,
            @RequestParam(required = false) String q, @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng) {
        return searchService.search(vertical, q, lat, lng);
    }
}
