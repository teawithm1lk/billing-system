package ru.romanov.sergey.billingsystem.controller.dto.callbynumber;

import lombok.AllArgsConstructor;
import lombok.Getter;

import java.sql.Timestamp;
import java.time.Duration;

@Getter
@AllArgsConstructor
public class CallDTO {
    private String callType;
    private Timestamp startTime;
    private Timestamp endTime;
    private String duration;
    private Double cost;

    public CallDTO(String callType, Timestamp startTime, Timestamp endTime, long duration, Double cost) {
        this.callType = callType;
        this.startTime = startTime;
        this.endTime = endTime;
        Duration millisDuration = Duration.ofSeconds(duration);
        this.duration = String.format("%d:%d:%d", millisDuration.toHours(),
                millisDuration.toMinutesPart(), millisDuration.toSecondsPart());
        this.cost = cost;
    }
}
