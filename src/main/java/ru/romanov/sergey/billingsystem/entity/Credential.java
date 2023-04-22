package ru.romanov.sergey.billingsystem.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;

@Entity
@Table
@Getter
@Setter
@NoArgsConstructor
public class Credential {
    @Id
    @Column
    private String userPhone;

    @Column
    private String userPassword;

    @JoinColumn(name = "role_id", nullable = false)
    @ManyToOne(fetch = FetchType.EAGER)
    private Role role;

    public Credential(String userPhone, String userPassword, Role role) {
        this.userPhone = userPhone;
        this.userPassword = userPassword;
        this.role = role;
    }

    public List<Role> getRoles() {
        return List.of(getRole());
    }
}
