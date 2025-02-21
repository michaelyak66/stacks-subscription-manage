import React, { useState } from 'react';
import { useAccount, useAuth,  useOpenContractCall } from '@micro-stacks/react';

const RenewButton = () => {
  const [message, setMessage] = useState('');
  const { stxAddress } = useAccount(); // To check if the user is signed in
  const { isSignedIn, signIn, signOut } = useAuth(); // Micro-Stacks auth hooks
  const {openContractCall} = useOpenContractCall(); // Invoke as a hook here

  const contractAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"; // Local deployer address
  const contractName = "subscription";
  const handleRenew = async () => {
    if (!isSignedIn) {
      setMessage("❌ Please connect your wallet to proceed.");
      return;
    }

    try {
      // Here, you can use useContractCall to call your `renew` function from your contract
      const result = await openContractCall({
        contractAddress: contractAddress, // Replace with your contract address
        contractName: contractName, // Replace with your contract name
        functionName: 'renew', // The function you want to call in your contract
        functionArgs: [], // Arguments for the renew function if any
      });

      // Check for success
      if (result.success) {
        setMessage('Renewal successful!');
      } else {
        setMessage('Renewal failed: ' + result.errorMessage);
      }
    } catch (error) {
      console.error("Error renewing subscription:", error);
      setMessage("❌ Renewal failed");
    }
  };

  return (
    <div className="p-4">
      <button
        onClick={handleRenew}
        className="w-full bg-yellow-400 text-purple-800 py-3 my-3 rounded-lg font-bold shadow-lg hover:bg-yellow-500 hover:text-purple-900 transition-transform transform hover:scale-105"
      >
        Renew Now
      </button>
      {message && (
        <p className="mt-4 text-center text-white bg-purple-500 p-2 rounded-lg shadow-md">
          {message}
        </p>
      )}
    </div>
  );
};

export default RenewButton;
