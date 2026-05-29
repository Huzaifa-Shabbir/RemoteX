import express from "express";
import PairToken from "../models/PairToken.js";
import { randomBytes } from "crypto";

const router = express.Router();

// PC creates pairing token
router.post("/create", async (req, res) => {
  try {
    const { deviceId } = req.body;

    // create token valid for 5 minutes
    const token = randomBytes(4).toString("hex"); 
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

    const pairToken = new PairToken({ token, deviceId, expiresAt });
    await pairToken.save();

    res.json({ token, expiresAt });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Phone connects using token
router.post("/connect", async (req, res) => {
  try {
    const { token, deviceId } = req.body;

    const pair = await PairToken.findOne({ token });

    if (!pair) return res.status(400).json({ error: "Invalid token" });

    if (pair.expiresAt < new Date()) {
      await PairToken.deleteOne({ token });
      return res.status(400).json({ error: "Token expired" });
    }

    // Here you can mark devices as paired, e.g., update device records
    await PairToken.deleteOne({ token }); // token used, remove it

    res.json({ success: true, pairedDeviceId: pair.deviceId });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;