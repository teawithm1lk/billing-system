package ru.romanov.sergey.billingsystem.service;

import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;
import ru.romanov.sergey.billingsystem.entity.Payment;
import ru.romanov.sergey.billingsystem.repository.PaymentRepository;

import java.util.List;

@Service
public class PaymentService {
    private final PaymentRepository paymentRepository;
    private final PhoneService phoneService;

    public PaymentService(PaymentRepository paymentRepository, PhoneService phoneService) {
        this.paymentRepository = paymentRepository;
        this.phoneService = phoneService;
    }

    public Payment findPaymentById(Integer id) {
        return paymentRepository.findById(id)
                .orElseThrow(EntityNotFoundException::new);
    }

    public List<Payment> findAllPayments() {
        return (List<Payment>) paymentRepository.findAll();
    }

    public List<Payment> findPaymentsByPhone(String phone) {
        return paymentRepository.findPaymentByPhone(phoneService.findUserById(phone));
    }

    public Payment save(Payment payment) {
        return paymentRepository.save(payment);
    }
}
