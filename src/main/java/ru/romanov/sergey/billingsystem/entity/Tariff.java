package ru.romanov.sergey.billingsystem.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Entity
@Table
@Getter
@Setter
@NoArgsConstructor
public class Tariff {
    @Id
    @Column
    private String tariffId;

    @Column
    private String tariffName;

    @Column
    private Integer periodPrice;

    @Column
    private Integer minutesBalanceOut;

    @Column
    private Integer minutesBalanceIn;

    @Column
    private Integer minutesBalanceSummary;

    @Column
    private Double minutePriceOut;

    @Column
    private Double minutePriceIn;

    @Column
    private Double expiredMinutePriceOut;

    @Column
    private Double expiredMinutePriceIn;

    @OneToMany(mappedBy = "tariff", fetch = FetchType.EAGER, cascade = CascadeType.ALL)
    private List<Phone> phones;

    public Tariff(String tariffId, String tariffName, Integer periodPrice,
                  Integer minutesBalanceOut, Integer minutesBalanceIn, Integer minutesBalanceSummary,
                  Double minutePriceOut, Double minutePriceIn,
                  Double expiredMinutePriceOut, Double expiredMinutePriceIn) {
        this.tariffId = tariffId;
        this.tariffName = tariffName;
        this.periodPrice = periodPrice;
        this.minutesBalanceOut = minutesBalanceOut;
        this.minutesBalanceIn = minutesBalanceIn;
        this.minutesBalanceSummary = minutesBalanceSummary;
        this.minutePriceOut = minutePriceOut;
        this.minutePriceIn = minutePriceIn;
        this.expiredMinutePriceOut = expiredMinutePriceOut;
        this.expiredMinutePriceIn = expiredMinutePriceIn;
    }
}
