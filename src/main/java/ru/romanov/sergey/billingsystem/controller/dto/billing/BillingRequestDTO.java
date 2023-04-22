package ru.romanov.sergey.billingsystem.controller.dto.billing;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class BillingRequestDTO {
    private String action;
    private int year;
    private int month;
}
