package ru.romanov.sergey.billingsystem.util;

import java.io.FileWriter;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.*;

public class CDRGeneration {
    private static final int NUMBER_OF_LINES = 100000;
    private static final String[] CALL_TYPES = {"01", "02"};
    private static final String SDF_PATTERN = "yyyyMMddHHmmss";
    private static final int MONTH_PERIOD_NUMBER = 1;
    private static final int DAY_OF_PERIOD = 1;
    private static final long DISTRIBUTION_IN_MILLISECONDS = 3 * 60 * 60 * 1000L;

    public static void generate(int year, int month, List<String> numbers) {
        Random random = new Random();
        SimpleDateFormat sdf = new SimpleDateFormat(SDF_PATTERN);

        final int FORMATTED_CALENDAR_MONTH = month - 1;
        Calendar startDate = new GregorianCalendar(year, FORMATTED_CALENDAR_MONTH, DAY_OF_PERIOD);
        Calendar endDate = (Calendar) startDate.clone();
        endDate.add(Calendar.MONTH, MONTH_PERIOD_NUMBER);
        final long DISTRIBUTION_INSIDE_MONTH = endDate.getTimeInMillis() - startDate.getTimeInMillis();

        try(FileWriter writer = new FileWriter("cdr.txt", false)) {
            for (int i = 0; i < NUMBER_OF_LINES; i++) {
                String callType = CALL_TYPES[random.nextInt(2)];
                String number = numbers.get(random.nextInt(numbers.size()));

                Date startAtLine = new Date(startDate.getTimeInMillis() + random.nextLong(DISTRIBUTION_INSIDE_MONTH));
                final long TIME_UNTIL_NEXT_MONTH = endDate.getTimeInMillis() - startAtLine.getTime();
                Date endAtLine = new Date(startAtLine.getTime()
                        + random.nextLong(Math.min(DISTRIBUTION_IN_MILLISECONDS, TIME_UNTIL_NEXT_MONTH)));

                String startTimestamp = sdf.format(startAtLine);
                String endTimestamp = sdf.format(endAtLine);
                writer.write(String.format("%s,%s,%s,%s\n", callType, number, startTimestamp, endTimestamp));
            }
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
}
