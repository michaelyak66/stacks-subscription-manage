import React, { useState } from "react";
import { useAuth, useOpenContractCall, useAccount } from "@micro-stacks/react";
import { uintCV } from "@stacks/transactions"; // Import uintCV from Clarity library
import { Link } from "react-router-dom";

const SubscribeForm = () => {
  const [amount, setAmount] = useState("");
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(false); // Loading state
  const contractAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"; // Local deployer address
  const contractName = "subscription";

  const { isSignedIn, signIn, signOut } = useAuth(); // Micro-Stacks auth hooks
  const { stxAddress } = useAccount();
  const {openContractCall} = useOpenContractCall(); // Invoke as a hook here

  const handleSubscribe = async () => {
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
      // Convert `amount` to uint before passing it to the contract call
      const uintAmount = parseInt(amount);
  
      // Ensure that the amount is a valid uint
      if (isNaN(uintAmount) || uintAmount <= 0) {
        setMessage("❌ Invalid amount. Please enter a positive number.");
        setLoading(false);
        return;
      }
      
      console.log("Attempting to subscribe with amount:", uintAmount);
      const functionArgs = [uintCV(parseInt(amount))];

      const contractCallOptions = {
        contractAddress: contractAddress, // Replace with your contract address
        contractName: contractName, // Replace with your contract name
        functionName: "subscribe",
        functionArgs: functionArgs,
        // postConditionMode: 0x01, // Specify post-condition mode (optional)
        onFinish: (data) => {
          console.log("Transaction finished:", data);
          setMessage("🎉 Subscription successful!");
        },
        onCancel: () => {
          setMessage("❌ Transaction canceled.");
        },
      };
  
      // Open the contract call dialog
      await openContractCall(contractCallOptions);
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

      {!isSignedIn ? (
        <button
          onClick={signIn}
          className="w-full bg-blue-500 text-black py-3 rounded-lg font-bold shadow-md hover:bg-blue-300 transition-transform transform hover:scale-105"
        >
          Connect Wallet
        </button>
      ) : (
        <>
          <p className="text-gray-400 text-sm text-center mb-4">
            Connected as: <strong>{stxAddress}</strong>
          </p>
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
          <button
            onClick={signOut}
            className="w-full mt-4 bg-red-500 text-black py-3 rounded-lg font-bold shadow-md hover:bg-red-300 transition-transform transform hover:scale-105"
          >
            Disconnect Wallet
          </button>
      <Link
          to="/">

          <button
            className="w-full mt-4 bg-green-500 text-black py-3 rounded-lg font-bold shadow-md hover:bg-red-300 transition-transform transform hover:scale-105"
            >
            Home
          </button>
            </Link>
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

export default SubscribeForm;
