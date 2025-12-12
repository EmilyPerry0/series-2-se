package benchmark;

public class Item {

    private final String name;
    private double price;

    public Item(String name, double price) {
        this.name = name;
        this.price = price;
    }

    // T1 Clone Class Member 1/2: Exact Duplicate
    // @CloneClass T1-A (1/2) | Cloned in OrderProcessor.calculateTotalTax()
    public double calculateTotalTax() {
        if (price < 10.0) {
            return price * 0.05; // 5% tax
        } else {
            return price * 0.08; // 8% tax
        }
    }

    // T3 Clone Class Member 1/3: Syntactically Similar (Added Statement)
    // @CloneClass T3-B (1/3) | Cloned in OrderProcessor.processOrder() and Order.getShippingCost()
    public void printItemDetails(String customer) {
        System.out.println("--- Item Details ---"); // Added
        System.out.println("Item: " + this.name);
        System.out.println("Price: " + this.price);
        System.out.println("Customer: " + customer);
    }

    // --- Start of T2 Clone Class C (10 members) ---
    // T2 Clone Class Member 1/10: Variable name change
    // @CloneClass T2-C (1/10) | Cloned in Item.dummyMethod2-10, OrderProcessor.dummyMethod1-4, and Order.dummyMethod1-5
    private int dummyMethod1() {
        int valA = 100;
        int valB = 50;
        for (int i = 0; i < 5; i++) {
            valA += i;
        }
        return valA + valB;
    }

    // T2 Clone Class Member 2/10: Identifier and literal change
    // @CloneClass T2-C (2/10) | Cloned in Item.dummyMethod1, dummyMethod3-10, OrderProcessor.dummyMethod1-4, and Order.dummyMethod1-5
    private int dummyMethod2() {
        int valueX = 100; // Identifier change (valA -> valueX)
        int valueY = 50;  // Identifier change (valB -> valueY)
        for (int j = 0; j < 5; j++) { // Identifier change (i -> j)
            valueX += j;
        }
        return valueX + valueY;
    }

    // T2 Clone Class Member 3/10: Identifier and literal change
    // @CloneClass T2-C (3/10) | Cloned in Item.dummyMethod1-2, dummyMethod4-10, OrderProcessor.dummyMethod1-4, and Order.dummyMethod1-5
    private int dummyMethod3() {
        int a = 200; // Literal change (100 -> 200)
        int b = 50;
        for (int k = 0; k < 5; k++) {
            a += k;
        }
        return a + b;
    }

    // T2 Clone Class Member 4/10: Identifier and literal change
    // @CloneClass T2-C (4/10) | Cloned in Item.dummyMethod1-3, dummyMethod5-10, OrderProcessor.dummyMethod1-4, and Order.dummyMethod1-5
    private int dummyMethod4() {
        int x = 100;
        int y = 10; // Literal change (50 -> 10)
        for (int l = 0; l < 5; l++) {
            x += l;
        }
        return x + y;
    }

    // T2 Clone Class Member 5/10: Identifier change
    // @CloneClass T2-C (5/10) | Cloned in Item.dummyMethod1-4, dummyMethod6-10, OrderProcessor.dummyMethod1-4, and Order.dummyMethod1-5
    private int dummyMethod5() {
        int aValue = 100;
        int bValue = 50;
        for (int m = 0; m < 5; m++) {
            aValue += m;
        }
        return aValue + bValue;
    }

    // --- End of T2 Clone Class C (Members 1-5/10) ---

    // Getters and Setters
    public String getName() {
        return name;
    }

    public double getPrice() {
        return price;
    }

    public void setPrice(double price) {
        this.price = price;
    }
}