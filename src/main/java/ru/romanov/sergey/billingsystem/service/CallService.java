package ru.romanov.sergey.billingsystem.service;

import org.springframework.stereotype.Component;
import ru.romanov.sergey.billingsystem.entity.Call;
import ru.romanov.sergey.billingsystem.repository.CallRepository;

import java.sql.Timestamp;
import java.util.List;

@Component
public class CallService {
    private final CallRepository callRepository;
    private final PhoneService phoneService;

    public CallService(CallRepository callRepository, PhoneService phoneService) {
        this.callRepository = callRepository;
        this.phoneService = phoneService;
    }

    public Call findCallById(Integer id) {
        return callRepository.findById(id)
                .orElseThrow(RuntimeException::new);
    }

    public List<Call> findAllCalls() {
        return (List<Call>)callRepository.findAll();
    }

    public List<Call> findCallsByPhoneNumber(String phoneNumber) {
        return callRepository.findCallsByPhone(phoneService.findUserById(phoneNumber));
    }

    public Call save(Call call) {
        return callRepository.save(call);
    }

    public boolean existsCallByPhoneAndTimestamp(String phoneNumber, Timestamp timestamp) {
        return callRepository.existsByPhoneEqualsAndStartTimestampEquals(phoneService.findUserById(phoneNumber), timestamp);
    }
}
