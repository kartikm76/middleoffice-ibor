package com.kmakker.ibor.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.util.Map;

@RestControllerAdvice
class BindingAdvice {
    @ExceptionHandler(org.springframework.web.bind.MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.UNPROCESSABLE_ENTITY)
    Map<String, Object> onValidation(MethodArgumentNotValidException ex){ return Map.of("error","validation", "details", ex.getMessage()); }

    @ExceptionHandler(org.springframework.web.bind.MissingServletRequestParameterException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    Map<String, Object> onMissing(MissingServletRequestParameterException ex){ return Map.of("error","missing_param", "param", ex.getParameterName()); }

    @ExceptionHandler(org.springframework.web.method.annotation.MethodArgumentTypeMismatchException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    Map<String, Object> onTypeMismatch(MethodArgumentTypeMismatchException ex){
        return Map.of("error","type_mismatch","param", ex.getName(), "value", String.valueOf(ex.getValue()), "requiredType", String.valueOf(ex.getRequiredType()));
    }
}