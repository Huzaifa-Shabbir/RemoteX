import mongoose from "mongoose";

const deviceSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true }, // from Supabase
  deviceName: String,
  deviceType: { type: String, enum: ["pc", "mobile"] },
  status: { type: String, default: "offline" },
}, { timestamps: true });

export default mongoose.model("Device", deviceSchema);