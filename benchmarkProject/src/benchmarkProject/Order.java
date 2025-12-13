package benchmarkProject;

//--- Class 3: Order.java ---
public class Order {

private final String id;
private final Item[] items;

public Order(String id, Item[] items) {
   this.id = id;
   this.items = items;
}

// T3 Clone Class Member 3/3: Syntactically Similar (Added Statement and Type Change)
// @CloneClass T3-B (3/3) | Cloned in Item.printItemDetails() and OrderProcessor.processOrder()
// T3: This method returns a double, the others are void. This is a common T3 characteristic.
public double getShippingCost(String customer) {
   // System.out.println("--- Item Details ---"); // Deleted
   System.out.println("Order ID: " + this.id); // Changed 'Item' to 'Order ID'
   System.out.println("Customer: " + customer);
   // Calculates a base shipping cost
   double baseCost = 5.0 + (items.length * 1.5);
   return baseCost;
}

// --- Start of T2 Clone Class C (10 members) ---
// T2 Clone Class Member 10/10: Literal change 
// @CloneClass T2-C (10/10) | Cloned in Item.dummyMethod1-5, OrderProcessor.dummyMethod1-4
private int dummyMethod1_Order() { 
   int value1 = 100; // Literal change 
   int value2 = 50;  // Literal change
   for (int s = 0; s < 5; s++) {
       value1 += s;
   }
   return value1 + value2;
}
// --- End of T2 Clone Class C (Member 10/10) ---

// Helper methods (T2 clones for padding, 4 extra for a total of 14)
private int dummyMethod2_Order() {
   int varA = 100;
   int varB = 50;
   for (int t = 0; t < 5; t++) {
       varA += t;
   }
   return varA + varB;
}

private int dummyMethod3_Order() {
   int varA = 100;
   int varB = 50;
   for (int u = 0; u < 5; u++) {
       varA += u;
   }
   return varA + varB;
}

private int dummyMethod4_Order() {
   int varA = 100;
   int varB = 50;
   for (int v = 0; v < 5; v++) {
       varA += v;
   }
   return varA + varB;
}

private int dummyMethod5_Order() {
   int varA = 100;
   int varB = 50;
   for (int w = 0; w < 5; w++) {
       varA += w;
   }
   return varA + varB;
}
}