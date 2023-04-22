package ru.romanov.sergey.billingsystem.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.postgresql.util.PGInterval;

import java.sql.Timestamp;

@Entity
@Table
@Data
@NoArgsConstructor
public class Call{
    @Id
    @Column
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Integer callId;

    @JoinColumn(name = "user_phone", nullable = false)
    @ManyToOne(fetch = FetchType.EAGER)
    private Phone phone;

    @Column
    private Timestamp startTimestamp;

    @Column
    private Timestamp endTimestamp;

    @Column
    private PGInterval duration;

    private Double cost;

    public Call(Integer callId, Phone phone, Timestamp startTimestamp, Timestamp endTimestamp) {
        this.callId = callId;
        this.phone = phone;
        this.startTimestamp = startTimestamp;
        this.endTimestamp = endTimestamp;
    }
}
