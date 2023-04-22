package ru.romanov.sergey.billingsystem.security;

import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import ru.romanov.sergey.billingsystem.entity.Credential;
import ru.romanov.sergey.billingsystem.service.CredentialService;

public class AuthProvider implements AuthenticationProvider {
    private final CredentialService credentialService;

    public AuthProvider(CredentialService credentialService) {
        this.credentialService = credentialService;
    }

    @Override
    public Authentication authenticate(Authentication authentication) throws AuthenticationException {
        String name = authentication.getName();
        String password = (String) authentication.getCredentials();
        Credential credential = credentialService.findCredentialByLogin(name);

        if (credential == null) {
            throw new UsernameNotFoundException("Such phone number was not found!");
        }
        if (!credential.getUserPassword().equals(password)) {
            throw new BadCredentialsException("Incorrect password!");
        }

        return new UsernamePasswordAuthenticationToken(credential, password, credential.getRoles());
    }

    @Override
    public boolean supports(Class<?> authentication) {
        return authentication.equals(UsernamePasswordAuthenticationToken.class);
    }
}
