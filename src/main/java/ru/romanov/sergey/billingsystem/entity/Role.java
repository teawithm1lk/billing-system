package ru.romanov.sergey.billingsystem.entity;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.security.core.GrantedAuthority;

import java.util.List;

@Entity
@Table
@Getter
@Setter
@NoArgsConstructor
@ToString
public class Role implements GrantedAuthority {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column
    private Integer roleId;

    @Column
    private String roleName;

    @OneToMany(mappedBy = "role", fetch = FetchType.EAGER, cascade = CascadeType.ALL)
    private List<Credential> credentials;

    public Role(String roleName) {
        this.roleName = roleName;
    }

    @Override
    public String getAuthority() {
        return roleName;
    }
}
