package ru.romanov.sergey.billingsystem.service;

import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;
import ru.romanov.sergey.billingsystem.entity.ChangeTariff;
import ru.romanov.sergey.billingsystem.repository.ChangeTariffRepository;

import java.util.List;

@Service
public class ChangeTariffService {
    private final ChangeTariffRepository changeTariffRepository;

    public ChangeTariffService(ChangeTariffRepository changeTariffRepository) {
        this.changeTariffRepository = changeTariffRepository;
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
