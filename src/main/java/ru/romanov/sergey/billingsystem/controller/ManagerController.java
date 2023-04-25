package ru.romanov.sergey.billingsystem.controller;

import jakarta.persistence.EntityNotFoundException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import ru.romanov.sergey.billingsystem.controller.dto.billing.BillingRequestDTO;
import ru.romanov.sergey.billingsystem.controller.dto.billing.BillingResponseDTO;
import ru.romanov.sergey.billingsystem.controller.dto.changetariff.ChangeTariffRequestDTO;
import ru.romanov.sergey.billingsystem.controller.dto.changetariff.ChangeTariffResponseDTO;
import ru.romanov.sergey.billingsystem.controller.dto.phone.PhoneRequestDTO;
import ru.romanov.sergey.billingsystem.controller.dto.phone.PhoneResponseDTO;
import ru.romanov.sergey.billingsystem.entity.ChangeTariff;
import ru.romanov.sergey.billingsystem.entity.Phone;
import ru.romanov.sergey.billingsystem.entity.Tariff;
import ru.romanov.sergey.billingsystem.service.BillingService;
import ru.romanov.sergey.billingsystem.service.ChangeTariffService;
import ru.romanov.sergey.billingsystem.service.PhoneService;
import ru.romanov.sergey.billingsystem.service.TariffService;

import java.util.List;

@RestController
@RequestMapping(path = "/manager")
public class ManagerController {
    private final PhoneService phoneService;
    private final ChangeTariffService changeTariffService;
    private final BillingService billingService;
    private final TariffService tariffService;

    public ManagerController(PhoneService phoneService, ChangeTariffService changeTariffService, BillingService billingService, TariffService tariffService) {
        this.phoneService = phoneService;
        this.changeTariffService = changeTariffService;
        this.billingService = billingService;
        this.tariffService = tariffService;
    }

    @PatchMapping(
            path = "/billing",
            consumes = "application/json",
            produces = "application/json"
    )
    public ResponseEntity<List<BillingResponseDTO>> billingEndpoint(
            @RequestBody BillingRequestDTO request
    ) {
        try {
            return ResponseEntity.ok().body(billingService.doBilling(request));
        } catch (EntityNotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }
    }

    @PostMapping(
            path = "/abonent",
            consumes = "application/json",
            produces = "application/json"
    )
    public ResponseEntity<PhoneResponseDTO> postAbonentEndpoint(
            @RequestBody PhoneRequestDTO request
    ) {
        try {
            Tariff tariff = tariffService.findTariffById(request.getTariffId());
            Phone phone = phoneService.save(new Phone(request.getNumberPhone(), tariff));
            return ResponseEntity.ok().body(new PhoneResponseDTO(phone.getUserPhone(), tariff.getTariffId(),
                    phone.getUserBalance()));
        } catch (EntityNotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }
    }

    @PostMapping(
            path = "/change-tariff",
            consumes = "application/json",
            produces = "application/json"
    )
    public ResponseEntity<ChangeTariffResponseDTO> postChangeTariffEndpoint(
            @RequestBody ChangeTariffRequestDTO request
    ) {
        try {
            Phone phone = phoneService.findUserById(request.getNumberPhone());
            Tariff tariff = tariffService.findTariffById(request.getTariffId());
            ChangeTariff ct = changeTariffService.save(new ChangeTariff(phone, tariff));
            return ResponseEntity.ok().body(new ChangeTariffResponseDTO(ct.getId(), ct.getPhone().getUserPhone(),
                    ct.getNewTariff().getTariffId()));
        } catch (EntityNotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }
    }
}
