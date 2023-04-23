package ru.romanov.sergey.billingsystem.controller;

import jakarta.persistence.EntityNotFoundException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import ru.romanov.sergey.billingsystem.controller.dto.callbynumber.CallByNumberResponseDTO;
import ru.romanov.sergey.billingsystem.controller.dto.callbynumber.CallDTO;
import ru.romanov.sergey.billingsystem.controller.dto.pay.PayRequestDTO;
import ru.romanov.sergey.billingsystem.controller.dto.pay.PayResponseDTO;
import ru.romanov.sergey.billingsystem.entity.Payment;
import ru.romanov.sergey.billingsystem.entity.Phone;
import ru.romanov.sergey.billingsystem.entity.Tariff;
import ru.romanov.sergey.billingsystem.service.CallService;
import ru.romanov.sergey.billingsystem.service.PaymentService;
import ru.romanov.sergey.billingsystem.service.PhoneService;

import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping(path = "/abonent")
public class AbonentController {
    private final CallService callService;
    private final PhoneService phoneService;
    private final PaymentService paymentService;

    public AbonentController(CallService callService, PhoneService phoneService, PaymentService paymentService) {
        this.callService = callService;
        this.phoneService = phoneService;
        this.paymentService = paymentService;
    }

    @GetMapping(
            path = "/report/{phoneNumber}",
            produces = "application/json"
    )
    public ResponseEntity<CallByNumberResponseDTO> getListCallsByNumberEndpoint(
            @PathVariable String phoneNumber
    ) {
        List<CallDTO> list = new ArrayList<>();
        Tariff tariff = phoneService.findUserById(phoneNumber).getTariff();
        callService.findCallsByPhoneNumber(phoneNumber).forEach(c -> {
            list.add(new CallDTO(c.getCallType(), c.getStartTimestamp(), c.getEndTimestamp(),
                    c.getDuration(), c.getCost()));
        });
        return ResponseEntity.ok()
                .body(new CallByNumberResponseDTO(phoneNumber, tariff.getTariffId(), list, tariff.getCurrency()));
    }

    @PostMapping(
        path = "/pay",
        consumes = "application/json",
        produces = "application/json"
    )
    public ResponseEntity<PayResponseDTO> abonentPayEndpoint(
        @RequestBody PayRequestDTO request
    ) {
        try {
            Phone phone = phoneService.findUserById(request.getNumberPhone());
            Payment p = paymentService.save(new Payment(phone, request.getMoney()));
            return ResponseEntity.ok().body(new PayResponseDTO(p.getId(), p.getPhone().getUserPhone(), p.getMoney()));
        } catch (EntityNotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }
    }
}
