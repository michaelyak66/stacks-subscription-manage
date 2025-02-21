import React from "react";
import RenewButton from "../components/RenewButton"; // Adjust path if necessary

const Renew = () => {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-gradient-to-r from-blue-400 to-purple-600">
      <div className="bg-purple-500 p-8 rounded-lg shadow-lg max-w-md w-full text-center">
        <h1 className="text-3xl font-bold text-white mb-4">Renew Subscription</h1>
        <p className="text-lg text-yellow-200 mb-6">
          Keep your subscription active and continue enjoying our premium services. Click below to renew!
        </p>
        <RenewButton />
      </div>
      <footer className="mt-6 text-yellow-100 text-sm">
        Made with ❤️ for seamless subscription management.
      </footer>
    </div>
  );
};

export default Renew;
