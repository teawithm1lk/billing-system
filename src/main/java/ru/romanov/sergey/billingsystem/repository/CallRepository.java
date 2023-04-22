package ru.romanov.sergey.billingsystem.repository;

import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;
import ru.romanov.sergey.billingsystem.entity.Call;
import ru.romanov.sergey.billingsystem.entity.Phone;

import java.util.List;

@Repository
public interface CallRepository extends CrudRepository<Call, Integer> {
    List<Call> findCallsByPhone(Phone phone);
}
