package ru.romanov.sergey.billingsystem.repository;

import org.springframework.data.repository.CrudRepository;
import ru.romanov.sergey.billingsystem.entity.ChangeTariff;

public interface ChangeTariffRepository extends CrudRepository<ChangeTariff, Integer> {
}
