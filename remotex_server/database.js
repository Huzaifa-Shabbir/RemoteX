import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config(); // load .env here

const mongoURI = process.env.MONGO_URI;

console.log("Mongo URI:", mongoURI);

mongoose.connect(mongoURI)
  .then(() => console.log("MongoDB connected"))
  .catch(err => console.log("MongoDB connection error:", err));