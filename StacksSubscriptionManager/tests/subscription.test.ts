import { describe, it, expect, beforeEach } from 'vitest';


const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;


// Mocking the blockchain state and contract functions
type Subscription = {
  endTime: number;
  tokensLocked: number;
};

const TOKEN_LOCK_DURATION = 2592000; // 30 days in seconds

let subscriptions: Map<string, Subscription>;

// Helper to get current time (simulate block time)
const getBlockTime = () => Math.floor(Date.now() / 1000);

// Contract functions to test
const subscribe = (user: string, amount: number) => {
  if (amount <= 0) throw new Error("Amount must be greater than 0");

  const endTime = getBlockTime() + TOKEN_LOCK_DURATION;
  subscriptions.set(user, { endTime, tokensLocked: amount });

  return endTime;
};

const renew = (user: string) => {
  const subscription = subscriptions.get(user);
  if (!subscription) throw new Error("No active subscription");

  const newEndTime = subscription.endTime + TOKEN_LOCK_DURATION;
  subscriptions.set(user, { ...subscription, endTime: newEndTime });

  return newEndTime;
};

const getSubscription = (user: string) => {
  return subscriptions.get(user) || null;
};

const isActive = (user: string) => {
  const subscription = subscriptions.get(user);
  return subscription ? subscription.endTime >= getBlockTime() : false;
};

// Tests using Vitest
describe("Subscription Contract", () => {
  const user = "wallet_1";

  beforeEach(() => {
    // Reset the subscriptions before each test
    subscriptions = new Map();
  });

  it("should allow a user to subscribe", () => {
    const amount = 100;
    const endTime = subscribe(user, amount);

    const subscription = getSubscription(user);
    expect(subscription).toBeDefined();
    expect(subscription?.tokensLocked).toBe(amount);
    expect(subscription?.endTime).toBe(endTime);
  });

  it("should throw an error for invalid subscription amount", () => {
    expect(() => subscribe(user, 0)).toThrow("Amount must be greater than 0");
  });

  it("should allow a user to renew their subscription", () => {
    const amount = 100;
    subscribe(user, amount);

    const newEndTime = renew(user);
    const subscription = getSubscription(user);

    expect(subscription).toBeDefined();
    expect(subscription?.endTime).toBe(newEndTime);
  });

  it("should throw an error if trying to renew without an active subscription", () => {
    expect(() => renew(user)).toThrow("No active subscription");
  });

  it("should correctly identify an active subscription", () => {
    subscribe(user, 100);
    expect(isActive(user)).toBe(true);
  });

  it("should correctly identify an expired subscription", () => {
    // Simulate expired subscription by setting a past end time
    subscriptions.set(user, { endTime: getBlockTime() - 1000, tokensLocked: 100 });
    expect(isActive(user)).toBe(false);
  });
});

describe("simnet", () => {
  it("ensures simnet is well initalised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  // it("shows an example", () => {
  //   const { result } = simnet.callReadOnlyFn("counter", "get-counter", [], address1);
  //   expect(result).toBeUint(0);
  // });
});
