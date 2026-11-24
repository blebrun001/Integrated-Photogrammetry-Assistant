<p align="center">
  <img src="IPA/Assets.xcassets/AppIcon.appiconset/IPA512.png" alt="Integrated Photogrammetry Assistant logo" width="140" />
</p>

# Integrated Photogrammetry Assistant

Integrated Photogrammetry Assistant 2 is a macOS application developed at IPHES-CERCA by Brice Lebrun for reconstructing, documenting and publishing archaeological objects. Each session works with one object. Source photos stay at their original locations.

## Working with an object

1. Drop photos or a folder into **Photos**. In **Review**, check thumbnails for blur, clipped highlights and clipped shadows. Adjust each tolerance, rerun analysis or select images manually.
2. Open **Reconstruction** to choose detail, ordering, sensitivity, masking, texture compression and cleanup. Choose an output directory when starting. RealityKit processes the selected images and the resulting OBJ or USDZ opens in the Viewer.
3. Open **Viewer** directly to inspect an existing model. Orbit the camera, switch between four surface styles, or pick two surface points. In calibration mode enter one or more known distances in centimetres and apply the mean of their scale factors. Drag in rotation mode or enter angles in degrees. **Undo edit** reverses the latest edit.
4. For an OBJ with a textured Micro QR marker, **Auto Scale** provides an alternative. Select the texture and marker size, detect the symbol, then confirm the factor and choose a copy or replacement. Under **Tools → Print QR markers**, print the PDF on A4 at 100% and check the physical side length before capture.

The photo selection, open model and calibration status last for the current session. Quality tolerances and reconstruction preferences persist between launches. Each model opened from disk starts with an unverified calibration status.

## Scientific illustrations and 3D exchange

The offline Viewer imports and exports OBJ, GLB, glTF, PLY, STL, USDZ and 3MF. Choose a destination when saving. Keep OBJ, MTL and texture files together. For unitless OBJ, STL and PLY, IPA exports coordinates in centimetres. GLB, glTF and USDZ exports use metres, and 3MF declares centimetres. Conversion dialogs describe format-specific losses. The exchange workflow targets static triangle meshes.

Export a PNG of an orthographic view, a multiview plate, a silhouette, an outline profile or a section at a chosen position along the viewing axis. Calibrated models can include a centimetre scale bar.

**Tools** also includes OBJ Renamer, Folder Structure, Bone Folder with UBERON lookup, README Generator and Dataverse Upload. These tools can be used before importing photos.

## Dataverse Upload Module
The **Dataverse upload** tool (under *Tools*) is now a native Integrated Photogrammetry Assistant module. It shares credentials with the global settings screen and requires:

- A Dataverse base URL (e.g. `https://demo.dataverse.org`).
- An API key with write access to the target dataset.
- The dataset persistent identifier (`doi:...`) that will be prefilled automatically when coming from the README Generator.

### Configuration & Options
- **Exclude regex** filters dotfiles or any custom pattern before uploads.
- **Direct upload** toggles the S3 presigned flow; the coordinator automatically falls back to server-side multipart uploads if the endpoint is missing (404) or the dataset exceeds the S3 limit.
- **Retries & backoff**: set maximum attempts, initial delay, and whether to resume automatically on transient URLError/POSIX codes.
- **Index refresh**: refresh by time or by file count to keep remote duplicate detection in sync.
- **Checksum matching**: optionally compute MD5/SHA checksums locally when the Dataverse draft listing exposes them for reliable deduplication.

### Runtime Behaviour
- Security-scoped bookmarks are resolved for each dropped folder/file so the sandbox can read the content.
- Duplicate detection runs both before and after each upload using the remote draft file list (path+size or path+checksum).
- Progress shows the current file, byte-transfer text, and a console-style log with retry hints.
- Direct uploads stream straight to the storage provider; if a file exceeds the provider limit or the server rejects the request, Integrated Photogrammetry Assistant switches to the multipart fallback automatically without losing progress.
- Practical limits follow the Dataverse deployment configuration (typical direct-upload size caps mirror the backing object store, while server-side multipart handles very large files but is constrained by HTTP timeouts).

## Project Layout
- `IPA/`
  - `General/` – Scene setup, global settings, shared UI.
  - `Internationalization/` – Localization resources and language picker utilities.
  - `Modules/` – Feature groups (3D creation, dataset preparation, file management).
  - `Assets.xcassets/`, `Sounds/`, `Preview Content/` – Media and design resources.
- `IPATests/`, `IPAUITests/` – Unit and UI test targets.
- `ViewerKit/` – Source and pinned npm dependencies for the bundled offline Viewer.

## Requirements
- macOS 15.2 or later.
- Xcode 16.2 or later with a macOS 15.2 or newer SDK.
- Apple Silicon or Intel Mac capable of running RealityKit photogrammetry workflows.

## Getting Started
1. Clone the repository and ensure submodules (if any) are initialised.
2. Open `IPA.xcodeproj` in Xcode.
3. Select the `IPA` scheme and build/run on macOS.
4. Provide the necessary Dataverse credentials under **Settings → General** before using upload features.

## Releases
Tagged versions matching `v*` are built by GitHub Actions as unsigned macOS release archives. The packaged app is named `Integrated Photogrammetry Assistant.app`.

Because release builds are unsigned and not notarized, macOS Gatekeeper will warn before opening the downloaded app.

## Localization
Integrated Photogrammetry Assistant supports four interface languages:
- English *(default UI language)*
- French
- Spanish
- Catalan

The active language can be changed at runtime from the toolbar globe button. Switching languages restarts the app to reload localized resources.

## Development Notes

- The bundled Viewer builds with the app offline. After editing its JavaScript sources, run `cd ViewerKit && npm ci && npm run build` to refresh the checked-in bundle.
- In `ViewerKit`, run `npx playwright-core install chromium` and `npm test` to check textured round trips, units, calibration, rotations and the graphical scale. Set `CHROME_PATH` to use an existing Chrome installation.
- The optional reconstruction integration test accepts a photo directory via `TEST_RUNNER_IPA_CAPTURE_FIXTURE` when running `xcodebuild test`. It reconstructs a preview in a temporary directory and opens it in the embedded Viewer.
- Project preferences are stored via `AppStorage` in `SettingsManager`.
- Photogrammetry sessions are coordinated by `PhotogrammetryManager`, which also supervises export clean-up.
- Micro QR detection and auto-scaling live inside `AutoScaleViewModel` and related views.
- When adding new UI text, use `NSLocalizedString` with a descriptive comment and add translations in `Internationalization/Localizable.xcstrings`.

## Funding Acknowledgement
This work is part of the *Esqueletos en línea* project led by Dr. Palmira Saladié (IPHES-CERCA), funded by the María de Guzmán programme of the Fundación Española para la Ciencia y la Tecnología.

## License
Licensed under the GNU General Public License, Version 3, 29 June 2007.

See `LICENSE` for the full license text.
