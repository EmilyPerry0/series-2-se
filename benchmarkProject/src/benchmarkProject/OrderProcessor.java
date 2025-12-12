package benchmarkProject;

public class OrderProcessor {

    // T1 Clone Class Member 2/2: Exact Duplicate
    // @CloneClass T1-A (2/2) | Cloned in Item.calculateTotalTax()
    public double calculateTotalTax(double price) {
        if (price < 10.0) {
            return price * 0.05; // 5% tax
        } else {
            return price * 0.08; // 8% tax
        }
    }

    // T3 Clone Class Member 2/3: Syntactically Similar (Deleted Statement)
    // @CloneClass T3-B (2/3) | Cloned in Item.printItemDetails() and Order.getShippingCost()
    public void processOrder(String customer, Item item) {
        // System.out.println("--- Item Details ---"); // Deleted
        System.out.println("Item: " + item.getName());
        System.out.println("Price: " + item.getPrice());
        System.out.println("Customer: " + customer);
        System.out.println("Processing complete..."); // Added change
    }

    // --- Start of T2 Clone Class C (10 members) ---
    // T2 Clone Class Member 6/10: Identifier change
    // @CloneClass T2-C (6/10) | Cloned in Item.dummyMethod1-5, dummyMethod7-10, Order.dummyMethod1-5
    private int dummyMethod1_OP() {
        int dataA = 100;
        int dataB = 50;
        for (int o = 0; o < 5; o++) {
            dataA += o;
        }
        return dataA + dataB;
    }

    // T2 Clone Class Member 7/10: Literal change
    // @CloneClass T2-C (7/10) | Cloned in Item.dummyMethod1-5, dummyMethod6, dummyMethod8-10, Order.dummyMethod1-5
    private int dummyMethod2_OP() {
        int valA = 100;
        int valB = 100; // Literal change (50 -> 100)
        for (int p = 0; p < 5; p++) {
            valA += p;
        }
        return valA + valB;
    }

    // T2 Clone Class Member 8/10: Identifier and Literal change
    // @CloneClass T2-C (8/10) | Cloned in Item.dummyMethod1-5, dummyMethod6-7, dummyMethod9-10, Order.dummyMethod1-5
    private int dummyMethod3_OP() {
        int temp1 = 150; // Literal change (100 -> 150)
        int temp2 = 50;
        for (int q = 0; q < 5; q++) {
            temp1 += q;
        }
        return temp1 + temp2;
    }

    // T2 Clone Class Member 9/10: Identifier change
    // @CloneClass T2-C (9/10) | Cloned in Item.dummyMethod1-5, dummyMethod6-8, dummyMethod10, Order.dummyMethod1-5
    private int dummyMethod4_OP() {
        int val_a = 100;
        int val_b = 50;
        for (int r = 0; r < 5; r++) {
            val_a += r;
        }
        return val_a + val_b;
    }
    // --- End of T2 Clone Class C (Members 6-9/10) ---

    // Standard business logic methods would go here
}