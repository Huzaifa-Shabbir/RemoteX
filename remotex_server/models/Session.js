import mongoose from "mongoose";

const sessionSchema = new mongoose.Schema({
  sessionId: { type: String, required: true, unique: true },

  userId: { type: String, required: true, index: true },

  hostDeviceId: String,
  clientDeviceId: String,

  status: { type: String, default: "waiting" }, // waiting, active, ended
}, { timestamps: true });

export default mongoose.model("Session", sessionSchema);