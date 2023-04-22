package ru.romanov.sergey.billingsystem.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import ru.romanov.sergey.billingsystem.controller.dto.changetariff.ChangeTariffRequestDTO;
import ru.romanov.sergey.billingsystem.entity.ChangeTariff;
import ru.romanov.sergey.billingsystem.entity.Phone;
import ru.romanov.sergey.billingsystem.service.ChangeTariffService;
import ru.romanov.sergey.billingsystem.service.PhoneService;

@RestController
@RequestMapping(name = "/manager")
public class ManagerController {
    private final PhoneService phoneService;
    private final ChangeTariffService changeTariffService;

    public ManagerController(PhoneService phoneService, ChangeTariffService changeTariffService) {
        this.phoneService = phoneService;
        this.changeTariffService = changeTariffService;
    }

//    @PatchMapping(
//            path = "/billing",
//            consumes = "application/json",
//            produces = "application/json"
//    )
//    public ResponseEntity<List<BillingResponseDTO>> billingEndpoint(
//            @RequestBody BillingRequestDTO request
//    ) {
//
//    }

    @PostMapping(
            path = "/abonent",
            consumes = "application/json",
            produces = "application/json"
    )
    public ResponseEntity<Phone> postAbonentEndpoint(
            @RequestBody Phone request
    ) {
        return ResponseEntity.ok().body(phoneService.save(request));
    }

    @PostMapping(
            path = "/change-tariff",
            consumes = "application/json",
            produces = "application/json"
    )
    public ResponseEntity<ChangeTariff> postChangeTariffEndpoint(
            @RequestBody ChangeTariffRequestDTO request
    ) {
        return ResponseEntity.ok().body(changeTariffService.save(request));
    }
}
