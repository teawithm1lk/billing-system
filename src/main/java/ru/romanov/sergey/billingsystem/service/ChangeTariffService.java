package ru.romanov.sergey.billingsystem.service;

import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Component;
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

    public ChangeTariff findChangeTariffById(Integer id) {
        return changeTariffRepository.findById(id)
                .orElseThrow(EntityNotFoundException::new);
    }

    public List<ChangeTariff> findAllChangeTariffs() {
        return (List<ChangeTariff>) changeTariffRepository.findAll();
    }

    public ChangeTariff save(ChangeTariff changeTariff) {
        return changeTariffRepository.save(changeTariff);
    }
}
