/**
 * Enum representing the status of the knapsack object.
 * IN_PROGRESS: The knapsack is still being processed and does not yet fulfill the value threshold nor does it violate the maximal weight constraint.
 * FAILED: Knapsack violated the maximum weight constraint.
 * SUCCEEDED: Knapsack did not violate max weight constraint and fulfilled the value threshold.
 */
public enum Status {
    IN_PROGRESS, FAILED, SUCCEEDED;
}
