package ru.romanov.sergey.billingsystem.controller.dto.changetariff;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class ChangeTariffRequestDTO {
    private String numberPhone;
    private String tariffId;
}
