package ru.romanov.sergey.billingsystem.service;

import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Component;
import ru.romanov.sergey.billingsystem.entity.Tariff;
import ru.romanov.sergey.billingsystem.repository.TariffRepository;

import java.util.List;

@Component
public class TariffService {
    private final TariffRepository tariffRepository;

    public TariffService(TariffRepository tariffRepository) {
        this.tariffRepository = tariffRepository;
    }

    public Tariff findTariffById(String id) {
        return tariffRepository.findById(id)
                .orElseThrow(EntityNotFoundException::new);
    }

    public List<Tariff> findAllTariffs() {
        return (List<Tariff>) tariffRepository.findAll();
    }

    public Tariff save(Tariff tariff) {
        return tariffRepository.save(tariff);
    }
}
