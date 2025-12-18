import java.util.ArrayList;
import java.util.List;

/**
 * A class representing a individual knapsack, with all containing items, their sum of gold values and their sum of weight.
 * The status field describes if the knapsack is still processed, already failed the requirement or succeeded the requrirements.
 */
public class Knapsack {
    private Status status;
    private final List<Item> items;
    private float weightSum;
    private int valueSum;
    
    Knapsack(Status status, List<Item> items, float weightSum, int valueSum){
        this.status = status;
        this.items = items;
        this.weightSum = weightSum;
        this.valueSum = valueSum;
    }

    public Knapsack() {
        items = new ArrayList<>();
        weightSum = 0.0f;
        valueSum = 0;
        status = Status.IN_PROGRESS;
    }

    public void addItem(Item item) {
        items.add(item);
        weightSum += item.weight();
        valueSum += item.value();
    }

    public void setStatus(Status status) {
        this.status = status;
    }

    public Status status() {
        return status;
    }

    public List<Item> items() {
        return items;
    }

    public float weightSum() {
        return weightSum;
    }

    public int valueSum() {
        return valueSum;
    }

    public Knapsack copy() {
        return new Knapsack(status, new ArrayList<>(items), weightSum, valueSum);
    }
}
