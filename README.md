# SubchainFlexPro Smart Contract

SubchainFlexPro is a Clarity smart contract for managing subscription plans and user subscriptions on the Stacks blockchain. It provides functionality for creating, updating, and managing subscription plans, as well as subscribing users and handling administrative actions.

## Features

- **Plan Management:**  
  Create, update, transfer, freeze, and remove subscription plans.

- **Subscription Management:**  
  Subscribe users to plans, remove subscriptions, and query subscription details.

- **Admin Controls:**  
  Transfer contract admin rights, force pause (freeze) plans, and remove subscriptions.

## Limitations

- **Clarity 1.x Restrictions:**  
  - No support for `map-keys` or `range` functions.
  - Cannot enumerate all plans or subscriptions on-chain.
  - Clients must iterate from `0` to `plan-counter - 1` and call `get-plan` for each plan ID to fetch all plans.
  - Clients must track their own subscriptions or iterate over possible keys client-side.

## Usage

### Query a Plan
```clarity
(get-plan plan-id)
```

### Query a Subscription
```clarity
(get-subscription subscriber plan-id)
```

### Remove a Subscription (Admin)
```clarity
(remove-subscription subscriber plan-id)
```

### Transfer Admin Rights
```clarity
(transfer-admin new-admin)
```

## Client-Side Recommendations

To list all active plans or subscriptions, iterate from `0` to `plan-counter - 1` and call the appropriate read-only function for each ID. Filter results client-side for active plans or subscriptions.

