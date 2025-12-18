import javax.swing.*;
import javax.swing.filechooser.FileNameExtensionFilter;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

public class Main {

    private static final String SEPARATOR = ";"; //Separator character used in CSV File
    private static final AtomicLong count = new AtomicLong(0); //Counting variable to determine how many iterations of knapsack were run.
    private static final AtomicBoolean solutionFound = new AtomicBoolean(false); // Atomic boolean, which is set to true if a thread has found a solution. Other threads will then cancel.
    private static List<Item> items;
    private static float maxWeight;
    private static int valueThreshold;

    public static void main(String[] args) throws IOException {
        items = processAndValidateCsv(pickFile());
        items.sort(Comparator.comparingInt(Item::value).reversed());
        maxWeight = getFloatInput();
        valueThreshold = getIntegerInput();

        long start = System.currentTimeMillis();
        //Knapsack result = knapsack(new Knapsack());
        Knapsack result = parallelKnapsack();
        Duration duration = Duration.ofMillis(System.currentTimeMillis() - start);

        if (result.status().equals(Status.SUCCEEDED)) {
            System.out.println("Valid knapsack found:");
            for (Item item : result.items()) {
                System.out.println("\t" + item);
            }
            System.out.printf("Total Weight: %.2f%n", result.weightSum());
            System.out.printf("Total Value: %d%n", result.valueSum());
            System.out.printf("Took %d milliseconds%n", duration.toMillis());

            verifyResult(result, duration);
        } else {
            System.out.printf("No valid Knapsack found.\nTook: %d milliseconds.%n", duration.toMillis());
        }

        System.out.printf("A total of %d different subsets were computed.", count.get());
    }

    /**
     * Method used to start FilePicker Dialog.
     * @return CSV File
     */
    public static File pickFile() {
        JFileChooser fileChooser = new JFileChooser(System.getProperty("user.dir"));
        FileNameExtensionFilter csvFilter =
                new FileNameExtensionFilter("CSV Dateien (*.csv)", "csv");
        fileChooser.addChoosableFileFilter(csvFilter);
        fileChooser.setFileFilter(csvFilter);
        fileChooser.setAcceptAllFileFilterUsed(false);
        int result = fileChooser.showOpenDialog(null);
        if (result == JFileChooser.APPROVE_OPTION) {
            return fileChooser.getSelectedFile();
        } else {
            return null;
        }
    }

    /**
     * Method used to verify result of recursive knapsack method and compare duration of verification to duration of calculation.
     * Runs in linear runtime.
     * @param result Knapsack object, which was calculated before and in Status SUCCEEDED.
     * @param oldDuration Time it took to calculate result.
     */
    private static void verifyResult(Knapsack result, Duration oldDuration) {
        System.out.println("\nVerification:");
        System.out.println("Value:");
        long start = System.currentTimeMillis();
        int sum = 0;
        float weight = 0.0f;
        for (Item item : result.items()) {
            sum += item.value();
            weight += item.weight();
        }
        Duration duration = Duration.ofMillis(System.currentTimeMillis() - start);
        for (Item item : result.items()) {
            System.out.printf("+ %10d\n", item.value());
        }
        System.out.printf("Sum: %d\n", sum);
        if (sum >= valueThreshold) {
            System.out.printf("Check succeeded: Value %d greater or equal than Threshold %d\n", sum, valueThreshold);
        } else {
            System.out.println("Critical Error");
            return;
        }
        System.out.println("Weight:");
        for (Item item : result.items()) {
            System.out.printf("+ %10.2f\n", item.weight());
        }
        if (weight <= maxWeight) {
            System.out.printf("Check suceeded: Weight %.2f smaller or equal than maximal weight %.2f\n", weight, maxWeight);
        } else {
            System.out.println("Critical Error");
            return;
        }
        System.out.printf("Verification took %d milliseconds\n", duration.toMillis());
        System.out.printf("The verification took %3.2f %% of the time, which was used to compute the result.\n", duration.toMillis() * 100.0 / oldDuration.toMillis());
    }

    /**
     * Recursive method to brute force calculate a knapsack, which fulfills both the value and maximal weight constraint.
     * @param knapsack Knapsack in Status IN_PROGRESS.
     * @return Knapsack object in Status SUCCEEDED OR FAILED.
     */
    private static Knapsack knapsack(Knapsack knapsack) {
        if (knapsack.valueSum() >= valueThreshold && knapsack.weightSum() <= maxWeight) {
            // Set Status to succeeded if criteria was met.
            knapsack.setStatus(Status.SUCCEEDED);
            count.getAndSet(count.longValue() + 1);
            return knapsack;
        } else if (knapsack.weightSum() > maxWeight || solutionFound.get()) {
            // Weight constraint has been violated or another thread found a solution -> cancel execution.
            count.getAndSet(count.longValue() + 1);
            knapsack.setStatus(Status.FAILED);
            return knapsack;
        }

        // Iterate over all items and add a random item, which is not already in the knapsack.
        for (Item item : items) {
            if (!containsReference(knapsack.items(), item)) {
                Knapsack copy = knapsack.copy();
                copy.addItem(item);
                Knapsack result = knapsack(copy);
                if (result.status().equals(Status.SUCCEEDED)) {
                    // If a valid knapsack was found, return that.
                    return result;
                }
            }
        }
        // If no valid configuration was found return a failed knapsack.
        knapsack.setStatus(Status.FAILED);
        return knapsack;
    }

    /**
     * Method to execute the knapsack method in parallel with multiple CPU cores.
     * @return Knapsack object in Status SUCCEEDED OR FAILED.
     */
    private static Knapsack parallelKnapsack() {
        int numCores = Runtime.getRuntime().availableProcessors();

        final Knapsack[] finalResult = new Knapsack[1];
        ExecutorService executor = Executors.newFixedThreadPool(numCores - 1);

        // Give each thread a new knapsack with an item from the items list.
        // By iterating over every item, eventually every possible configuration will be calculated, if no SUCCEEDED knapsack was found beforehand.
        for (int i = 0; i < items.size(); i++) {
            int finalI = i;
            executor.submit(() -> {
                Item initialItem = items.get(finalI);
                if (!solutionFound.get()) {
                    Knapsack knapsack = new Knapsack();
                    knapsack.addItem(initialItem);

                    Knapsack result = knapsack(knapsack);

                    // If a SUCCEEDED knapsack is returned, save it and set solutionFound to true, so that the other threads stop their calculations.
                    if (result.status().equals(Status.SUCCEEDED)) {
                        synchronized (Main.class) {
                            if (finalResult[0] == null) {
                                finalResult[0] = result;
                                solutionFound.set(true);
                            }
                        }
                    }
                }
            });
        }

        // Shut down the thread pool and wait for termination of threads.
        try {
            executor.shutdown();

            executor.awaitTermination(10, TimeUnit.MINUTES);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        return finalResult[0] == null ? new Knapsack(Status.FAILED, null, 0, 0) : finalResult[0];
    }

    /**
     * Custom method to check if a item is already in a given list of items.
     * Uses reference based check, because multiple items with same name, value and weight can exist.
     * @param list List of Skyrim items
     * @param item Item object, which should be checked if it is contained in the list.
     * @return true if given item is in the list. false if not.
     */
    public static boolean containsReference(List<Item> list, Item item) {
        for (Item existingItem : list) {
            // Hier wird die Referenzgleichheit geprüft (speicherortgleich)
            if (existingItem == item) {
                return true;
            }
        }
        return false;
    }

    /**
     * Method to validate given CSV-File.
     * Checks if it has 3 columns, with the pre-defined values of name, weight and value.
     * @param csvFile CSV-File
     * @return a list of Items.
     * @throws IOException when File does not exist or is not in the right format.
     */
    public static List<Item> processAndValidateCsv(File csvFile)
            throws IOException {

        List<Item> validatedData = new ArrayList<>();

        try (BufferedReader reader = new BufferedReader(new FileReader(csvFile))) {
            String line;

            if ((line = reader.readLine()) == null) {
                throw new IOException("Die Datei ist leer oder enthält keinen Header.");
            }

            while ((line = reader.readLine()) != null) {
                String[] columns = line.split(SEPARATOR, -1);

                if (columns.length != 3) {
                    throw new IOException(
                            String.format("Expected 3 columns, but found %d.", columns.length)
                    );
                }

                String column1_String = columns[0].trim();
                float column2_Float;
                int column3_Int;


                if (column1_String.isEmpty()) {
                    throw new IOException("First column must be a non empty string.");
                }

                try {
                    column2_Float = Float.parseFloat(columns[1].trim().replace(',', '.'));
                } catch (NumberFormatException e) {
                    throw new IOException(
                            "Second column must be a unsigned floating point number. Value: '" + columns[1].trim() + "'"
                    );
                }

                try {
                    column3_Int = Integer.parseInt(columns[2].trim());
                } catch (NumberFormatException e) {
                    throw new IOException(
                            "Third column must be a unsigned Integer. Value: '" + columns[2].trim() + "'"
                    );
                }

                validatedData.add(new Item(column1_String, column2_Float, column3_Int));
            }

        } catch (IOException e) {
            throw new IOException("Error when reading file: " + e.getMessage(), e);
        }

        return validatedData;
    }

    /**
     * Method starting a dialog window to read float value.
     * @return Float value.
     */
    public static float getFloatInput() {
        String input;
        Float result = null;

        while (result == null) {
            input = JOptionPane.showInputDialog(null, "Enter maximal Weight", "Enter maximal Weight", JOptionPane.QUESTION_MESSAGE);

            if (input == null) {
                throw new RuntimeException("Operation cancelled.");
            }

            try {
                String cleanedInput = input.trim().replace(',', '.');
                result = Float.parseFloat(cleanedInput);

                if (result < 0) {
                    JOptionPane.showMessageDialog(null, "Enter a positive number", "Error", JOptionPane.ERROR_MESSAGE);
                    result = null;
                }

            } catch (NumberFormatException e) {
                JOptionPane.showMessageDialog(null, "Invalid format! Enter a valid floating point number.", "Error", JOptionPane.ERROR_MESSAGE);
            }
        }
        return result;
    }

    /**
     * Method starting a dialog window to read integer value.
     * @return Integer value.
     */
    public static int getIntegerInput() {
        String input;
        Integer result = null;

        while (result == null) {
            input = JOptionPane.showInputDialog(null, "Enter value threshold", "Enter value threshold", JOptionPane.QUESTION_MESSAGE);

            if (input == null) {
                throw new RuntimeException("Operation cancelled.");
            }

            try {
                result = Integer.parseInt(input);

                if (result < 0) {
                    JOptionPane.showMessageDialog(null, "Enter a positive number", "Error", JOptionPane.ERROR_MESSAGE);
                    result = null;
                }

            } catch (NumberFormatException e) {
                JOptionPane.showMessageDialog(null, "Invalid format! Enter a valid natural number.", "Error", JOptionPane.ERROR_MESSAGE);
            }
        }
        return result;
    }
}
