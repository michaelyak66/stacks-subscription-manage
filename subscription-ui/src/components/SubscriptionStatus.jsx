import React, { useState } from 'react';
import { useAuth, useOpenContractCall, useAccount } from "@micro-stacks/react";

const SubscriptionStatus = () => {
  const [walletAddress, setWalletAddress] = useState('');
  const [subscription, setSubscription] = useState(null);
  const [active, setActive] = useState(false);
  const [error, setError] = useState(''); // State to store error messages
  const {openContractCall} = useOpenContractCall(); // Invoke as a hook here
  const contractAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"; // Local deployer address
  const contractName = "subscription";
  const { isSignedIn, stxAddress } = useAccount(); // To get the current wallet address

  const checkStatus = async () => {
    if (!walletAddress && !isSignedIn) {
      setError('❌ Please connect your wallet or provide a wallet address.');
      return;
    }
    setError(''); // Reset error state before attempting to fetch status

    try {
      // Replace these with the actual contract details and function names
      const [subscriptionDetails] = await openContractCall({
        contractAddress: contractAddress, // Replace with your contract address
        contractName: contractName, // Replace with your contract name
        functionName: 'get-subscription', // The function to fetch subscription details
        functionArgs: [walletAddress || stxAddress], // Pass the wallet address or connected user's address
      });

      console.log('Subscription details:', subscriptionDetails); // Log the subscription details
      setSubscription(subscriptionDetails);

      const [isActiveStatus] = await openContractCall({
        contractAddress: contractAddress, // Replace with your contract address
        contractName: contractName, // Replace with your contract name
        functionName: 'is-active', // The function to check if the subscription is active
        functionArgs: [walletAddress || stxAddress], // Pass the wallet address or connected user's address
      });

      console.log('Is active:', isActiveStatus); // Log the active status
      setActive(isActiveStatus);
    } catch (error) {
      setError('❌ Failed to fetch subscription details: ' + (error.message || 'Unknown error'));
    }
  };

  return (
    <div className="p-6 bg-white rounded-lg shadow-lg">
      <h2 className="text-xl font-semibold mb-4 text-purple-700">Check Subscription Status</h2>
      <input
        type="text"
        className="border border-gray-300 p-3 rounded-lg w-full mb-4 text-purple-700"
        placeholder="Enter wallet address"
        value={walletAddress}
        onChange={(e) => setWalletAddress(e.target.value)}
      />
      <button
        onClick={checkStatus}
        className="w-full bg-yellow-400 text-purple-800 py-3 rounded-lg font-bold shadow-md hover:bg-yellow-500 hover:text-purple-900 transition-transform transform hover:scale-105"
      >
        Check Status
      </button>

      {/* Display error message if there's any */}
      {error && (
        <div className="mt-4 text-red-500 font-semibold">
          <p>{error}</p>
        </div>
      )}

      {/* Display subscription details if available */}
      {subscription && !error && (
        <div className="mt-6">
          <div className="bg-purple-100 p-4 rounded-lg shadow-md">
            <p className="text-lg text-purple-700">End Time: {subscription.endTime}</p>
            <p className="text-lg text-purple-700">Tokens Locked: {subscription.tokensLocked}</p>
            <p className="text-lg text-purple-700">Status: {active ? 'Active' : 'Inactive'}</p>
          </div>
        </div>
      )}
    </div>
  );
};

export default SubscriptionStatus;
