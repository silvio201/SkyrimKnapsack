/**
 * A record class describing an item in Skyrim.
 * @param name Name of the item.
 * @param weight Weight of the item.
 * @param value Gold value of the item.
 */
public record Item (String name, float weight, int value) {

    @Override
    public String toString() {
        return "%s; Weight: %.2f; Value: %d".formatted(name, weight, value);
    }


}
