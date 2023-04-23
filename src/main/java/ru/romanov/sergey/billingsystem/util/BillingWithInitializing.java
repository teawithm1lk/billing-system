package ru.romanov.sergey.billingsystem.util;

import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import ru.romanov.sergey.billingsystem.controller.dto.billing.BillingRequestDTO;
import ru.romanov.sergey.billingsystem.service.BillingService;

import java.time.LocalDate;

@Component
public class BillingWithInitializing {
    private final BillingService billingService;

    public BillingWithInitializing(BillingService billingService) {
        this.billingService = billingService;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void doBillingWithInitialize() {
        billingService.doBilling(new BillingRequestDTO("run", LocalDate.now().getYear(), LocalDate.now().getMonthValue()));
        System.out.println("\n\n\n\n\nA\n\n\n\n");
    }
}
