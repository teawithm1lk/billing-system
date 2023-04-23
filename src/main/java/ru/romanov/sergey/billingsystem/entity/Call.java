package ru.romanov.sergey.billingsystem.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.sql.Timestamp;
import java.time.Duration;

@Entity
@Table
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Call{
    @Id
    @Column
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer callId;

    @Column
    private String callType;

    @JoinColumn(name = "user_phone", nullable = false)
    @ManyToOne(fetch = FetchType.EAGER)
    private Phone phone;

    @Column
    private Timestamp startTimestamp;

    @Column
    private Timestamp endTimestamp;

    @Column
    private Long duration;

    @Column
    private Double cost;

    public Call(String callType, Phone phone, Timestamp startTimestamp, Timestamp endTimestamp) {
        this.callType = callType;
        this.phone = phone;
        this.startTimestamp = startTimestamp;
        this.endTimestamp = endTimestamp;
        Duration da = Duration.between(startTimestamp.toLocalDateTime(), endTimestamp.toLocalDateTime());
        duration = da.toMillis();
        cost = 0.;
    }
}
