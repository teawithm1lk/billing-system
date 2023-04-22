package ru.romanov.sergey.billingsystem.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Entity
@NoArgsConstructor
public class Payment {
    @Id
    @Column
    @GeneratedValue
    private Integer id;

    @JoinColumn(name = "user_phone", nullable = false)
    @ManyToOne(fetch = FetchType.EAGER)
    private Phone phone;

    @Column
    private Double money;

    public Payment(Phone phone, Double money) {
        this.phone = phone;
        this.money = money;
    }
}
