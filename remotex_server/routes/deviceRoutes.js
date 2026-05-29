import express from "express";
import Device from "../models/Device.js";

const router = express.Router();

// Create Device
router.post("/create", async (req, res) => {
  try {
    const userId = req.user.sub; // from Supabase JWT

    const device = await Device.create({
      userId,
      deviceName: req.body.deviceName,
      deviceType: req.body.deviceType
    });

    res.json(device);

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get Devices
router.get("/", async (req, res) => {
  try {
    const userId = req.user.sub; // from Supabase JWT

    const devices = await Device.find({ userId });

    res.json(devices);

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;