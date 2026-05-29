import mongoose from "mongoose";

const fileSchema = new mongoose.Schema({
  fileName: String,
  fileUrl: String,
  filePath: String,

  uploadedBy: String,   // req.user.sub
  sessionId: String     // later for sharing

}, { timestamps: true });

export default mongoose.model("File", fileSchema);