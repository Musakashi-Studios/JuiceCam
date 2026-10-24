# Guide image uploader

`upload_guide_images.py` uploads guide screenshots to the `juicecam/guide` folder in Cloudinary. It uses only Python's standard library.

The script reads credentials from `.env` in the repository root, or from the `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET` environment variables. Environment variables take priority. `CLOUDINARY_URL` is also supported. The local `.env` file is ignored by Git.

Upload one or more images:

```powershell
python tools/upload_guide_images.py docs/images/cover-gameplay.png docs/images/camera-targets-inspector.png
```

Use `--dry-run` to preview asset IDs without contacting Cloudinary. Existing assets are preserved unless `--overwrite` is passed. The command prints each uploaded image's secure URL for use in the guide.
