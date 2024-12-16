import React, { useState } from "react";
import { subscribe } from "../services/stacksService";
import { useAuth } from "@micro-stacks/react";

export const SubscribeForm = () => {
  const [amount, setAmount] = useState("");
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(false); // Loading state
  const { isSignedIn, signIn, signOut } = useAuth();

  
  

  const { getSession } = useAuth();
  
  const handleSubscribe = async () => {
    if (!isSignedIn) {
      setMessage("❌ Please connect your wallet before subscribing.");
      return;
    }
  
    const session = getSession; // Retrieve the user session
    console.log("Session:", isSignedIn, session); // Log the session object
    if (!session) {
      setMessage("❌ Failed to retrieve user session.");
      return;
    }
  
    try {
      await subscribe(parseInt(amount), session); // Pass session to the service
      setMessage("🎉 Subscription successful!");
    } catch (error) {
      console.error("Error subscribing:", error);
      setMessage("❌ Subscription failed: " + error.message);
    }
  };
  

  const handleSubscribee = async () => {
    if (!isSignedIn) {
      setMessage("❌ Please connect your wallet before subscribing.");
      return;
    }

    if (!amount || parseInt(amount) <= 0) {
      setMessage("❌ Please enter a valid token amount greater than 0.");
      return;
    }

    setLoading(true);
    setMessage("");

    try {
      await subscribe(parseInt(amount));
      setMessage("🎉 Subscription successful!");
    } catch (error) {
      console.error("Error subscribing:", error);
      setMessage("❌ Subscription failed: " + error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="p-4 sm:p-8 max-w-lg mx-auto bg-white bg-opacity-10 rounded-lg shadow-lg backdrop-blur-md">
      <h2 className="text-2xl font-bold text-yellow-300 mb-6 text-center">
        Subscribe Now
      </h2>
      {console.log(isSignedIn)}
      {!isSignedIn ? (
        <button
          onClick={signIn}
          className="w-full bg-blue-500 text-black py-3 rounded-lg font-bold shadow-md hover:bg-blue-300 transition-transform transform hover:scale-105"
        >
          Connect Wallet
        </button>
      ) : (
        <>
          <div className="mb-6">
            <label
              htmlFor="amount"
              className="block text-gray-300 font-medium mb-2"
            >
              Enter Token Amount
            </label>
            <input
              type="number"
              id="amount"
              className="w-full p-3 rounded-lg border-2 border-gray-300 focus:outline-none focus:ring-2 focus:ring-yellow-400 focus:border-yellow-400"
              placeholder="e.g. 10"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
            />
          </div>
          <button
            onClick={handleSubscribe}
            className={`w-full ${
              loading
                ? "bg-gray-400 cursor-not-allowed"
                : "bg-yellow-400 hover:bg-yellow-300"
            } text-black py-3 rounded-lg font-bold shadow-md transition-transform transform ${
              loading ? "" : "hover:scale-105"
            }`}
            disabled={loading}
          >
            {loading ? "Processing..." : "Subscribe"}
          </button>
        </>
      )}

      {message && (
        <p
          className={`mt-4 text-center font-medium text-lg ${
            message.includes("successful")
              ? "text-green-500 animate-pulse"
              : "text-red-500"
          }`}
        >
          {message}
        </p>
      )}
    </div>
  );
};

// export default SubscribeForm;
