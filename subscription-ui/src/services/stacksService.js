import { AnchorMode, uintCV, principalCV, cvToJSON } from "@stacks/transactions";
import { useOpenContractCall, useNetwork, useAccount } from "@micro-stacks/react";

// Contract details
const contractAddress = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";
const contractName = "subscription";

// **Subscribe Function**
export const useSubscribe = () => {
  const openContractCall = useOpenContractCall();
  const network = useNetwork();

  const subscribe = async (amount) => {
    const functionArgs = [uintCV(amount)];

    const options = {
      contractAddress,
      contractName,
      functionName: "subscribe",
      functionArgs,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: 0x01, // PostConditionMode.Deny
      onFinish: (data) => {
        console.log("Transaction successful:", data);
      },
      onCancel: () => {
        console.log("Transaction canceled");
      },
    };

    await openContractCall(options);
  };

  return { subscribe };
};

// **Renew Function**
export const useRenew = () => {
  const openContractCall = useOpenContractCall();
  const network = useNetwork();

  const renew = async () => {
    const options = {
      contractAddress,
      contractName,
      functionName: "renew",
      functionArgs: [],
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: 0x01, // PostConditionMode.Deny
      onFinish: (data) => {
        console.log("Transaction successful:", data);
      },
      onCancel: () => {
        console.log("Transaction canceled");
      },
    };

    await openContractCall(options);
  };

  return { renew };
};

// **Get Subscription Function**
export const useGetSubscription = () => {
  const { stxAddress } = useAccount();
  const network = useNetwork();

  const getSubscription = async (walletAddress = stxAddress) => {
    if (!walletAddress || !walletAddress.startsWith("ST")) {
      throw new Error("Invalid wallet address");
    }

    const options = {
      contractAddress,
      contractName,
      functionName: "get-subscription",
      functionArgs: [principalCV(walletAddress)],
      network,
      senderAddress: walletAddress,
    };

    console.log("Options for read-only call:", JSON.stringify(options, null, 2));

    try {
      const result = await fetchCallReadOnlyFunction(options);
      console.log("Read-only function result:", cvToJSON(result));
      return cvToJSON(result); // Convert Clarity value to JSON for easier handling
    } catch (error) {
      console.error("Error fetching subscription details:", error);
      throw error;
    }
  };

  return { getSubscription };
};

// **Is Active Function**
export const useIsActive = () => {
  const { stxAddress } = useAccount();
  const network = useNetwork();

  const isActive = async (walletAddress = stxAddress) => {
    if (!walletAddress || !walletAddress.startsWith("ST")) {
      throw new Error("Invalid wallet address");
    }

    const options = {
      contractAddress,
      contractName,
      functionName: "is-active",
      functionArgs: [principalCV(walletAddress)],
      network,
      senderAddress: walletAddress,
    };

    console.log("Options for read-only call:", JSON.stringify(options, null, 2));

    try {
      const result = await fetchCallReadOnlyFunction(options);
      console.log("Read-only function result:", cvToJSON(result));
      return cvToJSON(result);
    } catch (error) {
      console.error("Error fetching active status:", error);
      throw error;
    }
  };

  return { isActive };
};
