package ru.romanov.sergey.billingsystem.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import ru.romanov.sergey.billingsystem.entity.Call;
import ru.romanov.sergey.billingsystem.entity.Payment;
import ru.romanov.sergey.billingsystem.entity.Phone;
import ru.romanov.sergey.billingsystem.entity.Tariff;
import ru.romanov.sergey.billingsystem.service.CallService;
import ru.romanov.sergey.billingsystem.service.PaymentService;

import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping(name = "/abonent")
public class AbonentController {
    private final CallService callService;
    private final PaymentService paymentService;

    public AbonentController(CallService callService, PaymentService paymentService) {
        this.callService = callService;
        this.paymentService = paymentService;
    }

    @GetMapping(
            path = "/report/{phoneNumber}",
            produces = "application/json"
    )
    public ResponseEntity<List<Call>> getListCallsByNumberEndpoint(
            @PathVariable String phoneNumber
    ) {
        List<Call> list = new ArrayList<>();
        callService.findCallsByPhoneNumber(phoneNumber).forEach(c -> {
            Phone p = c.getPhone();
            Tariff t = p.getTariff();
            list.add(new Call(c.getCallId(),
                    new Phone(phoneNumber,
                            new Tariff(t.getTariffId(), t.getTariffName(), t.getPeriodPrice(),
                                    t.getMinutesBalanceOut(), t.getMinutesBalanceIn(), t.getMinutesBalanceSummary(),
                                    t.getMinutePriceOut(), t.getMinutePriceIn(),
                                    t.getExpiredMinutePriceOut(), t.getExpiredMinutePriceIn()),
                            p.getMinutesBalance()),
                    c.getStartTimestamp(), c.getEndTimestamp()));
        });
        return ResponseEntity.ok().body(list);
    }

    @PostMapping(
        path = "/pay",
        consumes = "application/json",
        produces = "application/json"
    )
    public ResponseEntity<Payment> abonentPayEndpoint(
        @RequestBody Payment newPayment
    ) {
        return ResponseEntity.ok().body(paymentService.save(newPayment));
    }
}
