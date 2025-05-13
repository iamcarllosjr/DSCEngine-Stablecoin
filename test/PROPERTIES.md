# PROPERTIES
### We split properties into 5 main types:
- Valid States (Defines valid system states (e.g. “The balance must never be negative”)).
- State Transitions (Defines valid changes between states (e.g. “After liquidation, the collateral must be reduced”)).
- Variables Transitions (Rules on how variables should change (e.g. “The price of the token can only increase or decrease gradually”)).
- High-Level Properties (Comprehensive rules, often derived from business rules (e.g. “The sum of all collateral must cover the debts”)).
- Unit Tests (Specific tests, usually low-level and more technical).

| Properties       | Type        | Risk Level | Tested  |
|------------------|-------------|------------|---------|
| The total supply of collateral must be greater than the total DSC | High Level Properties  | High     | ✅      |
| 
The oracle price used in the protocol must always be within an acceptable deviation range from trusted external price feeds. | Variables Transitions | High       |    ✅    |
| If a user's collateral value falls below the required minimum threshold, then a liquidation must be triggered, reducing the user's collateral and covering their debt. | State Transitions | High     |    ✅    |