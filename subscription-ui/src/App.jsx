import { useState } from 'react';
// import reactLogo from './assets/react.svg';
import './App.css';
import * as MicroStacks from '@micro-stacks/react';
import React from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import Home from "./pages/Home";
import Subscribe from "./pages/Subscribe";
import Renew from './pages/Renew';
import Status from './pages/Status';

export default function App() {
  return (
    <MicroStacks.ClientProvider
      appName={'React + micro-stacks'}
      appIconUrl={"reactLogo"}
    >
      {/* <Contents /> */}
      <BrowserRouter>
      <div className="bg-gray-100 min-h-screen">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/subscribe" element={<Subscribe />} />
          <Route path="/renew" element={<Renew />} />
          <Route path="/status" element={<Status />} />
        </Routes>
      </div>
    </BrowserRouter>
    </MicroStacks.ClientProvider>
  );
}
