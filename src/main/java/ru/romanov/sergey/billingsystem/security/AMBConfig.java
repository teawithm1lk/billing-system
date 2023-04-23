package ru.romanov.sergey.billingsystem.security;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.authentication.builders.AuthenticationManagerBuilder;

import javax.sql.DataSource;

@Configuration
public class AMBConfig {
    private final DataSource dataSource;

    public AMBConfig(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Autowired
    public void configureGlobal(AuthenticationManagerBuilder auth) throws Exception {
        auth.jdbcAuthentication()
                .dataSource(dataSource)
                .usersByUsernameQuery("select user_phone, user_password, enabled "
                                    + "from credential "
                                    + "where user_phone = ?")
                .authoritiesByUsernameQuery("select user_phone, authority "
                                            + "from authority "
                                            + "where user_phone = ?");
    }
}
