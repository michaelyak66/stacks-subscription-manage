import { useAccount } from '@micro-stacks/react';

export const UserCard = () => {
  const { stxAddress } = useAccount();
  if (!stxAddress)
    return (
      <div className="bg-purple-700 p-4 rounded-lg shadow-md text-white text-center">
        <h3>No active session</h3>
      </div>
    );
  return (
    <div className="bg-purple-700 p-4 rounded-lg shadow-md text-white text-center">
      <h3>{stxAddress}</h3>
    </div>
  );
};
