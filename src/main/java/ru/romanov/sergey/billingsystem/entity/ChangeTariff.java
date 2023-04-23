package ru.romanov.sergey.billingsystem.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "change_tariff")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class ChangeTariff {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column
    private Integer id;

    @JoinColumn(name = "user_phone", nullable = false)
    @ManyToOne(fetch = FetchType.EAGER)
    private Phone phone;

    @JoinColumn(name = "new_tariff_id", nullable = false)
    @ManyToOne(fetch = FetchType.EAGER)
    private Tariff newTariff;

    public ChangeTariff(Phone phone, Tariff newTariff) {
        this.phone = phone;
        this.newTariff = newTariff;
    }
}
