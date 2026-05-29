import dotenv from "dotenv";
dotenv.config(); // ✅ MUST be first

import express from "express";
import cors from "cors";

import "./database.js"; // MongoDB connection

import { verifyToken } from "./middleware/auth.js";
import deviceRoutes from "./routes/deviceRoutes.js";
import fileRoutes from "./routes/fileRoutes.js";

const app = express();

// ========================
// 🧠 GLOBAL MIDDLEWARE
// ========================
app.use(cors());
app.use(express.json());

// ========================
// 🔐 PROTECTED ROUTES
// ========================
app.use("/devices", verifyToken, deviceRoutes);
app.use("/files", verifyToken, fileRoutes);

// ========================
// ❤️ HEALTH CHECK
// ========================
app.get("/", (req, res) => {
  res.send("Remotex backend running 🚀");
});

// ========================
// 🚀 START SERVER
// ========================
const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log("Server running on port " + PORT);
});