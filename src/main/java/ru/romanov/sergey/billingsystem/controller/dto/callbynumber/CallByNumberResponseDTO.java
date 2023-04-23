package ru.romanov.sergey.billingsystem.controller.dto.callbynumber;

import lombok.Getter;

import java.util.List;

@Getter
public class CallByNumberResponseDTO {
    private String phoneNumber;
    private String tariffIndex;
    private List<CallDTO> payload;
    private Double totalCost;
    private String monetaryUnit;

    public CallByNumberResponseDTO(String phoneNumber, String tariffIndex, List<CallDTO> payload, String monetaryUnit) {
        this.phoneNumber = phoneNumber;
        this.tariffIndex = tariffIndex;
        this.payload = payload;
        this.monetaryUnit = monetaryUnit;

        totalCost = 0.;
        payload.forEach(c -> totalCost += c.getCost());
    }
}
