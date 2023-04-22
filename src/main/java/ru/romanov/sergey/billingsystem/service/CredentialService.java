package ru.romanov.sergey.billingsystem.service;

import org.springframework.stereotype.Component;
import ru.romanov.sergey.billingsystem.entity.Credential;
import ru.romanov.sergey.billingsystem.repository.CredentialRepository;

import java.util.List;

@Component
public class CredentialService {
    private final CredentialRepository credentialRepository;

    public CredentialService(CredentialRepository credentialRepository) {
        this.credentialRepository = credentialRepository;
    }

    public Credential findCredentialByLogin(String login) {
        return credentialRepository.findById(login)
                .orElseThrow(RuntimeException::new);
    }

    public List<Credential> findAllCredentials() {
        return (List<Credential>) credentialRepository.findAll();
    }

    public Credential save(Credential credential) {
        return credentialRepository.save(credential);
    }

    public boolean isCorrectCredentials(String login, String rawPassword) {
        return findCredentialByLogin(login).getUserPassword().equals(rawPassword);
    }
}
