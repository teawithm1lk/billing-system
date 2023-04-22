package ru.romanov.sergey.billingsystem.service;

import org.springframework.stereotype.Component;
import ru.romanov.sergey.billingsystem.controller.dto.changetariff.ChangeTariffRequestDTO;
import ru.romanov.sergey.billingsystem.entity.ChangeTariff;
import ru.romanov.sergey.billingsystem.repository.ChangeTariffRepository;

import java.util.List;

@Component
public class ChangeTariffService {
    private final ChangeTariffRepository changeTariffRepository;
    private final PhoneService phoneService;
    private final TariffService tariffService;

    public ChangeTariffService(ChangeTariffRepository changeTariffRepository, PhoneService phoneService, TariffService tariffService) {
        this.changeTariffRepository = changeTariffRepository;
        this.phoneService = phoneService;
        this.tariffService = tariffService;
    }

    public ChangeTariff findTariffById(Integer id) {
        return changeTariffRepository.findById(id)
                .orElseThrow(RuntimeException::new);
    }

    public List<ChangeTariff> findAllTariffs() {
        return (List<ChangeTariff>) changeTariffRepository.findAll();
    }

    public ChangeTariff save(ChangeTariff changeTariff) {
        return changeTariffRepository.save(changeTariff);
    }

    public ChangeTariff save(ChangeTariffRequestDTO request) {
        return changeTariffRepository.save(new ChangeTariff(0, phoneService.findUserById(request.getUserPhone()),
                null, tariffService.findTariffById(request.getNewTariffId())));
    }
}
