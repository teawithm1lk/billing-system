package ru.romanov.sergey.billingsystem.controller.dto.pay;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class PayRequestDTO {
    private String numberPhone;
    private Double money;
}
