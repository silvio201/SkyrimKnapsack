public record Item (String name, float weight, int value) {

    @Override
    public String toString() {
        return "%s; Weight: %.2f; Value: %d".formatted(name, weight, value);
    }


}
