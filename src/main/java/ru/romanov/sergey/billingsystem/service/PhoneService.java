package ru.romanov.sergey.billingsystem.service;

import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;
import ru.romanov.sergey.billingsystem.entity.Phone;
import ru.romanov.sergey.billingsystem.repository.PhoneRepository;

import java.util.List;

@Service
public class PhoneService {
    private final PhoneRepository phoneRepository;

    public PhoneService(PhoneRepository phoneRepository) {
        this.phoneRepository = phoneRepository;
    }

    public Phone findUserById(String id) {
        return phoneRepository.findById(id)
                .orElseThrow(EntityNotFoundException::new);
    }

    public List<Phone> findAllUsers() {
        return (List<Phone>) phoneRepository.findAll();
    }

    public Phone save(Phone phone) {
        return phoneRepository.save(phone);
    }
}
