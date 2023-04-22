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
public class Phone {
    @Id
    @Column
    private String userPhone;

    @JoinColumn(name = "tariff_id", nullable = false)
    @ManyToOne(fetch = FetchType.EAGER)
    private Tariff tariff;

    @Column
    private Double userBalance;

    @Column
    private Integer minutesBalance;

    @OneToMany(mappedBy = "phone", fetch = FetchType.EAGER, cascade = CascadeType.ALL)
    private List<Call> calls;

    @OneToMany(mappedBy = "phone", fetch = FetchType.EAGER, cascade = CascadeType.ALL)
    private List<Payment> payments;

    @OneToMany(mappedBy = "phone", fetch = FetchType.EAGER, cascade = CascadeType.ALL)
    private List<ChangeTariff> changeTariffs;

    public Phone(String userPhone, Tariff tariff, Integer minutesBalance) {
        this.userPhone = userPhone;
        this.tariff = tariff;
        this.minutesBalance = minutesBalance;
    }
}
