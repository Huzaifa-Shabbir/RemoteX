import express from "express";
import multer from "multer";
import mongoose from "mongoose";
import File from "../models/File.js";
import { supabase } from "../config/supabase.js";

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

/**
 * 📤 UPLOAD FILE
 */
router.post("/upload", upload.single("file"), async (req, res) => {
  try {
    const file = req.file;
    const userId = req.user.id || req.user.sub;

    if (!file) {
      return res.status(400).json({ error: "No file uploaded" });
    }

    const filePath = `uploads/${Date.now()}-${file.originalname}`;

    // Upload to Supabase
    const { error: uploadError } = await supabase.storage
      .from("remotex-files")
      .upload(filePath, file.buffer);

    if (uploadError) {
      return res.status(500).json(uploadError);
    }

    // Save in MongoDB
    const fileDoc = await File.create({
      fileName: file.originalname,
      filePath,
      uploadedBy: userId
    });

    res.json(fileDoc);

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 📥 GET ALL FILES (CURRENT USER)
 */
router.get("/", async (req, res) => {
  try {
    const userId = req.user.id || req.user.sub;

    const files = await File.find({ uploadedBy: userId });

    res.json(files);

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 📄 GET SINGLE FILE (SIGNED URL)
 */
router.get("/:id", async (req, res) => {
  try {
    const userId = req.user.id || req.user.sub;
    const fileId = req.params.id;

    // ✅ Validate ObjectId (IMPORTANT FIX)
    if (!mongoose.Types.ObjectId.isValid(fileId)) {
      return res.status(400).json({ error: "Invalid file ID" });
    }

    const file = await File.findById(fileId);

    if (!file) {
      return res.status(404).json({ error: "File not found" });
    }

    if (file.uploadedBy !== userId) {
      return res.status(403).json({ error: "Not allowed" });
    }

    const { data, error } = await supabase.storage
      .from("remotex-files")
      .createSignedUrl(file.filePath, 60);

    if (error) {
      return res.status(500).json(error);
    }

    res.json({
      fileId: file._id,
      fileName: file.fileName,
      signedUrl: data.signedUrl
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * 🗑 DELETE FILE
 */
router.delete("/:id", async (req, res) => {
  try {
    const userId = req.user.id || req.user.sub;
    const fileId = req.params.id;

    if (!mongoose.Types.ObjectId.isValid(fileId)) {
      return res.status(400).json({ error: "Invalid file ID" });
    }

    const file = await File.findById(fileId);

    if (!file) {
      return res.status(404).json({ error: "File not found" });
    }

    if (file.uploadedBy !== userId) {
      return res.status(403).json({ error: "Not allowed" });
    }

    // Delete from Supabase
    const { error: storageError } = await supabase.storage
      .from("remotex-files")
      .remove([file.filePath]);

    if (storageError) {
      return res.status(500).json(storageError);
    }

    // Delete from MongoDB
    await File.findByIdAndDelete(fileId);

    res.json({ message: "File deleted successfully" });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


export default router;