import { useNetwork } from '@micro-stacks/react';
import { useAuth } from '@micro-stacks/react';

export const WalletConnectButton = () => {
  const { openAuthRequest, isRequestPending, signOut, isSignedIn } = useAuth();
  const label = isRequestPending ? 'Loading...' : isSignedIn ? 'Sign out' : 'Connect Stacks wallet';
  return (
    <div className="p-4 mb-5 rounded-lg shadow-md text-white text-center">
      <h4 className="font-semibold">Connect Wallet</h4>

    <button
      onClick={() => {
        if (isSignedIn) void signOut();
        else void openAuthRequest();
      }}
      className="bg-yellow-400 text-purple-800 mt-2 py-2 px-4 rounded-lg font-semibold shadow-md hover:bg-yellow-500 hover:text-purple-900 transition-transform transform hover:scale-105"
    >
      {label}
    </button>
    </div>

  );
};


export const NetworkToggle = () => {
  const { isMainnet, setNetwork } = useNetwork();
  const networkMode = isMainnet ? 'mainnet' : 'testnet';

  return (
    <div className="p-4 mb-5 rounded-lg shadow-md text-white text-center">
      <h4 className="font-semibold">Current network: {networkMode}</h4>
      <button
        onClick={() => setNetwork(isMainnet ? 'testnet' : 'mainnet')}
        className="mt-2 bg-blue-500 py-2 px-4 rounded-lg font-semibold text-white hover:bg-blue-600 transition-transform transform hover:scale-105"
      >
        Switch network
      </button>
    </div>
  );
};



export const ButtonContainer = () => {
    return (
      <div className="mt-5 mb-2 flex space-x-4 justify-center">
        <NetworkToggle />
        <WalletConnectButton />
      </div>
    );
  };
  