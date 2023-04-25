package ru.romanov.sergey.billingsystem.controller.dto.phone;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class PhoneResponseDTO {
    private String numberPhone;
    private String tariffId;
    private Double balance;
}
