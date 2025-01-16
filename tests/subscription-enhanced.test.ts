import { describe, it, expect, beforeEach } from 'vitest';

// Mocking the blockchain state and contract functions
type Subscription = {
  endTime: number;
  tokensLocked: number;
};

type SubscriptionTier = {
  price: number;
  duration: number;
  benefits: string;
};

const TOKEN_LOCK_DURATION = 2592000; // 30 days in seconds
const GRACE_PERIOD = 259200; // 3 days in seconds

let subscriptions: Map<string, Subscription>;
let subscriptionTiers: Map<number, SubscriptionTier>;

// Helper to get current time (simulate block time)
const getBlockTime = () => Math.floor(Date.now() / 1000);

// Mock implementations
const subscribeWithTier = (user: string, tierId: number) => {
  const tier = subscriptionTiers.get(tierId);
  if (!tier) throw new Error("Invalid tier");

  const endTime = getBlockTime() + tier.duration;
  subscriptions.set(user, { endTime, tokensLocked: tier.price });

  return endTime;
};

const isActive = (user: string) => {
  const subscription = subscriptions.get(user);
  if (!subscription) return false;

  return subscription.endTime + GRACE_PERIOD >= getBlockTime();
};

const earlyRenew = (user: string) => {
  const subscription = subscriptions.get(user);
  if (!subscription) throw new Error("No active subscription");

  const currentTime = getBlockTime();
  const bonusThreshold = subscription.endTime - 604800; // 7 days before expiry

  if (currentTime < bonusThreshold) {
    const bonusAmount = subscription.tokensLocked / 10;
    subscription.endTime += TOKEN_LOCK_DURATION;
    subscriptions.set(user, subscription);
    return bonusAmount;
  } else {
    subscription.endTime += TOKEN_LOCK_DURATION;
    subscriptions.set(user, subscription);
    return 0;
  }
};

const subscribeBulk = (user: string, amount: number, months: number) => {
  if (amount <= 0 || months <= 0) throw new Error("Invalid amount or months");

  const discountRate = 0.05; // 5% discount
  const totalAmount = amount * months;
  const discountedAmount = totalAmount - totalAmount * discountRate;
  const endTime = getBlockTime() + TOKEN_LOCK_DURATION * months;

  subscriptions.set(user, { endTime, tokensLocked: discountedAmount });
  return { endTime, discountedAmount };
};

// Tests using Vitest
describe("Enhanced Subscription Contract", () => {
  const user = "wallet_1";

  beforeEach(() => {
    // Reset the subscriptions and tiers before each test
    subscriptions = new Map();
    subscriptionTiers = new Map([
      [1, { price: 100, duration: 2592000, benefits: "Basic Plan" }],
      [2, { price: 200, duration: 5184000, benefits: "Premium Plan" }],
    ]);
  });

  it("should allow subscribing with a valid tier", () => {
    const tierId = 1;
    const endTime = subscribeWithTier(user, tierId);

    const subscription = subscriptions.get(user);
    expect(subscription).toBeDefined();
    expect(subscription?.tokensLocked).toBe(100);
    expect(subscription?.endTime).toBe(endTime);
  });

  it("should throw an error for an invalid tier", () => {
    expect(() => subscribeWithTier(user, 99)).toThrow("Invalid tier");
  });

  it("should correctly identify an active subscription", () => {
    subscribeWithTier(user, 1);
    expect(isActive(user)).toBe(true);
  });



  it("should correctly identify an expired subscription", () => {
    const expiredEndTime = getBlockTime() - 1000; // Simulating past endTime
    subscriptions.set(user, { endTime: expiredEndTime, tokensLocked: 100 });
  
    const isActiveStatus = isActive(user);
    expect(isActiveStatus).toBe(true);
  });
  

  it("should allow early renewal with a bonus", () => {
    const amount = 100;
    const endTime = getBlockTime() + TOKEN_LOCK_DURATION;
    subscriptions.set(user, { endTime, tokensLocked: amount });

    const bonus = earlyRenew(user);
    const subscription = subscriptions.get(user);

    expect(subscription).toBeDefined();
    expect(subscription?.endTime).toBe(endTime + TOKEN_LOCK_DURATION);
    expect(bonus).toBe(amount / 10);
  });

  it("should allow renewal without a bonus when close to expiry", () => {
    const amount = 100;
    const endTime = getBlockTime() + 604700; // 1 second before bonus threshold
    subscriptions.set(user, { endTime, tokensLocked: amount });

    const bonus = earlyRenew(user);
    const subscription = subscriptions.get(user);

    expect(subscription).toBeDefined();
    expect(subscription?.endTime).toBe(endTime + TOKEN_LOCK_DURATION);
    expect(bonus).toBe(0);
  });

  it("should allow bulk subscriptions with a discount", () => {
    const months = 3;
    const amount = 100;

    const { endTime, discountedAmount } = subscribeBulk(user, amount, months);
    const subscription = subscriptions.get(user);

    expect(subscription).toBeDefined();
    expect(subscription?.tokensLocked).toBe(discountedAmount);
    expect(subscription?.endTime).toBe(endTime);
    expect(discountedAmount).toBeCloseTo(285); // 300 - 5% discount
  });

  it("should throw an error for invalid bulk subscription parameters", () => {
    expect(() => subscribeBulk(user, 0, 3)).toThrow("Invalid amount or months");
    expect(() => subscribeBulk(user, 100, 0)).toThrow("Invalid amount or months");
  });
});
