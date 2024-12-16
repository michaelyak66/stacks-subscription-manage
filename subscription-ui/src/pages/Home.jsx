import React from "react";
import { Link } from "react-router-dom";
import { UserCard } from "../components/user-card.jsx";
import { ButtonContainer } from "../components/middle.jsx";
const Home = () => (
  <div className="bg-gradient-to-br from-blue-500 via-purple-600 to-indigo-700 text-white min-h-screen flex flex-col justify-center items-center">
    <div className="p-8 max-w-4xl mx-auto text-center bg-white bg-opacity-10 rounded-lg shadow-lg backdrop-blur-sm">
      <h1 className="text-4xl font-extrabold mb-6 tracking-wide">
        Welcome to <span className="text-yellow-300">Subscription Service</span>
      </h1>
      <p className="text-lg text-gray-200 mb-8 leading-relaxed">
        Subscribe, renew, and manage your subscriptions effortlessly with our 
        sleek and intuitive platform.
      </p>

      <div>
        <UserCard />
        <ButtonContainer/>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Link to Subscribe Page */}
        <Link
          to="/subscribe"
          className="bg-yellow-400 text-black px-6 py-3 rounded-lg font-medium shadow-md hover:bg-yellow-300 transition-transform transform hover:scale-105"
        >
          Subscribe Now
        </Link>

        {/* Link to Renew Page */}
        <Link
          to="/renew"
          className="bg-indigo-500 text-white px-6 py-3 rounded-lg font-medium shadow-md hover:bg-indigo-400 transition-transform transform hover:scale-105"
        >
          Renew Subscription
        </Link>

        {/* Link to Status Page */}
        <Link
          to="/status"
          className="bg-green-500 text-white px-6 py-3 rounded-lg font-medium shadow-md hover:bg-green-400 transition-transform transform hover:scale-105"
        >
          Check Status
        </Link>
      </div>
    </div>

    {/* Footer Section */}
    <footer className="mt-12 text-gray-300 text-sm">
      <p>
        Made with <span className="text-red-500">&hearts;</span> for seamless
        subscription management.
      </p>
    </footer>
  </div>
);

export default Home;
