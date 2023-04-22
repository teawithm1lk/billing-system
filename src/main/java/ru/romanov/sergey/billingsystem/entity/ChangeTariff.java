package ru.romanov.sergey.billingsystem.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "change_tariff")
@Getter
@Setter
@NoArgsConstructor
public class ChangeTariff {
    @Id
    @GeneratedValue
    @Column
    private Integer id;

    @JoinColumn(name = "user_phone", nullable = false)
    @ManyToOne(fetch = FetchType.EAGER)
    private Phone phone;

    @JoinColumn(name = "old_tariff_id", nullable = false)
    @ManyToOne(fetch = FetchType.EAGER)
    private Tariff oldTariffId;

    @JoinColumn(name = "new_tariff_id", nullable = false)
    @ManyToOne(fetch = FetchType.EAGER)
    private Tariff newTariffId;

    public ChangeTariff(Integer id, Phone phone, Tariff oldTariffId, Tariff newTariffId) {
        this.id = id;
        this.phone = phone;
        this.oldTariffId = oldTariffId;
        this.newTariffId = newTariffId;
    }
}
