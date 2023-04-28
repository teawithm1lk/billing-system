package ru.romanov.sergey.billingsystem.repository;

import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;
import ru.romanov.sergey.billingsystem.entity.Payment;
import ru.romanov.sergey.billingsystem.entity.Phone;

import java.util.List;

@Repository
public interface PaymentRepository extends CrudRepository<Payment, Integer> {
    List<Payment> findPaymentByPhone(Phone phone);
}
