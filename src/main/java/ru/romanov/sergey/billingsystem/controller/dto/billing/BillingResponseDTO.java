package ru.romanov.sergey.billingsystem.controller.dto.billing;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class BillingResponseDTO {
    private String phoneNumber;
    private Double balance;
}
