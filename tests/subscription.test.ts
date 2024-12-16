/**
 * This module provides a mock implementation of a subscription contract, including functions to subscribe, renew, and check the status of a subscription.
 * 
 * The subscription contract is represented by a `Subscription` type, which includes the end time of the subscription and the amount of tokens locked.
 * 
 * The main functions provided are:
 * - `subscribe(user: string, amount: number)`: Allows a user to subscribe to the contract, locking the specified amount of tokens for a 30-day period.
 * - `renew(user: string)`: Allows a user to renew their active subscription, extending the end time by another 30 days.
 * - `getSubscription(user: string)`: Returns the current subscription details for the specified user, or `null` if they have no active subscription.
 * - `isActive(user: string)`: Checks whether the user has an active subscription.
 * 
 * This implementation is intended for testing purposes and uses an in-memory `Map` to store the subscription details.
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';


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

describe("Referral System", () => {
  const user = "wallet_1";
  const referrer = "wallet_2";

  beforeEach(() => {
    subscriptions = new Map();
    referrals = new Map();
    vi.useFakeTimers();
  });

  it("should create a new referral record", () => {
    const amount = 100;
    subscribeWithReferral(user, amount, referrer);

    const referralData = getReferralData(referrer);
    expect(referralData).toBeDefined();
    expect(referralData?.totalReferrals).toBe(1);
    expect(referralData?.rewardsEarned).toBe(amount / 10); // 10% reward
  });

  it("should update existing referral record", () => {
    const amount1 = 100;
    const amount2 = 200;
    
    subscribeWithReferral("user1", amount1, referrer);
    subscribeWithReferral("user2", amount2, referrer);

    const referralData = getReferralData(referrer);
    expect(referralData?.totalReferrals).toBe(2);
    expect(referralData?.rewardsEarned).toBe((amount1 + amount2) / 10);
  });
});

describe("Subscription Pause", () => {
  const user = "wallet_1";

  beforeEach(() => {
    subscriptions = new Map();
    pausedSubscriptions = new Map();
    vi.useFakeTimers();

  });

  it("should pause an active subscription", () => {
    const amount = 100;
    subscribe(user, amount);
    
    pauseSubscription(user);
    
    const pausedSub = getPausedSubscription(user);
    expect(pausedSub).toBeDefined();
    expect(pausedSub?.pauseTime).toBeDefined();
    expect(pausedSub?.remainingTime).toBeGreaterThan(0);
    
    // Original subscription should be removed
    expect(getSubscription(user)).toBeNull();
  });

  it("should not pause non-existent subscription", () => {
    expect(() => pauseSubscription(user)).toThrow("No active subscription");
  });

  it("should calculate remaining time correctly", () => {
    const amount = 100;
    const subscribeTime = getBlockTime();
    subscribe(user, amount);
    
    // Simulate some time passing
    const pauseAfter = 1000; // seconds
    vi.advanceTimersByTime(pauseAfter * 1000); // Convert to milliseconds
    
    pauseSubscription(user);
    
    const pausedSub = getPausedSubscription(user);
    expect(pausedSub?.remainingTime).toBe(TOKEN_LOCK_DURATION - pauseAfter);
  });
});

// Add these helper functions at the top with your other mocks

type ReferralData = {
  totalReferrals: number;
  rewardsEarned: number;
};

type PausedSubscription = {
  pauseTime: number;
  remainingTime: number;
};

let referrals: Map<string, ReferralData>;
let pausedSubscriptions: Map<string, PausedSubscription>;

const subscribeWithReferral = (user: string, amount: number, referrer: string) => {
  subscribe(user, amount);
  
  const existingReferral = referrals.get(referrer);
  if (existingReferral) {
    referrals.set(referrer, {
      totalReferrals: existingReferral.totalReferrals + 1,
      rewardsEarned: existingReferral.rewardsEarned + (amount / 10)
    });
  } else {
    referrals.set(referrer, {
      totalReferrals: 1,
      rewardsEarned: amount / 10
    });
  }
};

const getReferralData = (referrer: string) => {
  return referrals.get(referrer) || null;
};

const pauseSubscription = (user: string) => {
  const subscription = getSubscription(user);
  if (!subscription) throw new Error("No active subscription");

  const currentTime = getBlockTime();
  const remainingTime = subscription.endTime - currentTime;

  pausedSubscriptions.set(user, {
    pauseTime: currentTime,
    remainingTime: remainingTime
  });

  subscriptions.delete(user);
};

const getPausedSubscription = (user: string) => {
  return pausedSubscriptions.get(user) || null;
};
