import { useNetwork } from '@micro-stacks/react';

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
