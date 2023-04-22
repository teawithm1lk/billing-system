package ru.romanov.sergey.billingsystem.repository;

import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;
import ru.romanov.sergey.billingsystem.entity.Phone;

@Repository
public interface PhoneRepository extends CrudRepository<Phone, String> {
}
