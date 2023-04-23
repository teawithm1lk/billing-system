package ru.romanov.sergey.billingsystem.controller.dto.changetariff;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class ChangeTariffResponseDTO {
    private Integer id;
    private String numberPhone;
    private String tariffId;
}
