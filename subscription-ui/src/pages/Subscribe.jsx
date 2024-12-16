import React from "react";
import SubscribeForm from "../components/SubscribeForm";

const Subscribe = () => (
  <div className="bg-gradient-to-br from-blue-500 via-purple-600 to-indigo-700 text-white min-h-screen flex flex-col justify-center items-center">
    <div className="p-8 max-w-4xl mx-auto text-center bg-white bg-opacity-10 rounded-lg shadow-lg backdrop-blur-sm">
      <h1 className="text-4xl font-extrabold mb-6 tracking-wide">
        <span className="text-yellow-300">Subscribe</span> to Our Service
      </h1>
      <p className="text-lg text-gray-200 mb-8 leading-relaxed">
        Secure your subscription today and enjoy uninterrupted access to our
        services.
      </p>
      <SubscribeForm />
    </div>
  </div>
);

export default Subscribe;
