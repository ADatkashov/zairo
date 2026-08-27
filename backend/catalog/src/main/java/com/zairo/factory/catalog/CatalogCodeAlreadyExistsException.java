package com.zairo.factory.catalog;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.CONFLICT)
public class CatalogCodeAlreadyExistsException extends RuntimeException {

    public CatalogCodeAlreadyExistsException(String message) {
        super(message);
    }
}
