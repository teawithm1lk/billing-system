package ru.romanov.sergey.billingsystem.service;

import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Component;
import ru.romanov.sergey.billingsystem.controller.dto.billing.BillingRequestDTO;
import ru.romanov.sergey.billingsystem.controller.dto.billing.BillingResponseDTO;
import ru.romanov.sergey.billingsystem.entity.Call;
import ru.romanov.sergey.billingsystem.entity.Phone;
import ru.romanov.sergey.billingsystem.util.CDRUtils;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.sql.Timestamp;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.List;

@Component
public class BillingService {
    private final CallService callService;
    private final PhoneService phoneService;

    public BillingService(CallService callService, PhoneService phoneService) {
        this.callService = callService;
        this.phoneService = phoneService;
    }

    public List<BillingResponseDTO> doBilling(BillingRequestDTO request) {
        if (!request.getAction().equals("run")) {
            throw new EntityNotFoundException();
        }

        List<BillingResponseDTO> list = new ArrayList<>();
        CDRUtils.generate(request.getYear(), request.getMonth(),
                phoneService.findAllUsers()
                        .stream()
                        .map(Phone::getUserPhone)
                        .toList());

        try(BufferedReader reader = new BufferedReader(new FileReader(CDRUtils.CDR_FILE_PATH))) {
            SimpleDateFormat sdf = new SimpleDateFormat(CDRUtils.SDF_PATTERN);
            String line;
            while ((line = reader.readLine()) != null) {
                String[] parameters = line.split(",");
                String callType = parameters[0];
                Phone phone = phoneService.findUserById(parameters[1]);
                if (phone.getUserBalance() > 0) {
                    Timestamp startTimestamp = new Timestamp(sdf.parse(parameters[2]).getTime());
                    Timestamp endTimestamp = new Timestamp(sdf.parse(parameters[3]).getTime());
                    if (!callService.existsCallByPhoneAndTimestamp(phone.getUserPhone(), startTimestamp)) {
                        callService.save(new Call(callType, phone, startTimestamp, endTimestamp));
                        if (list.stream().noneMatch(b -> b.getPhoneNumber().equals(phone.getUserPhone()))) {
                            list.add(new BillingResponseDTO(phone.getUserPhone(), phone.getUserBalance()));
                        }
                    }
                }
            }
        } catch (IOException | ParseException e) {
            throw new RuntimeException(e);
        }
        return list;
    }
}
