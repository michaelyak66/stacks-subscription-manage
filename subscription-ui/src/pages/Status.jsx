import React from "react";
import SubscriptionStatus from "../components/SubscriptionStatus";

const Status = () => {
  return (
    <div className="bg-gradient-to-r from-purple-600 via-blue-500 to-green-400 min-h-screen flex items-center justify-center">
      <div className="p-6 max-w-lg mx-auto bg-white rounded-lg shadow-lg">
        <h1 className="text-3xl font-bold text-center text-purple-700 mb-6">
          Subscription Status
        </h1>
        <SubscriptionStatus />
      </div>
    </div>
  );
};

export default Status;
