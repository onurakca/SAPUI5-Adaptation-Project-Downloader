# ZR_LREP_ADAPTATION_DOWNLOAD
ABAP report that downloads SAPUI5 Adaptation Project (App Variant) artifacts from the SAP Layered Repository (LREP) to the local file system.
## Purpose
When working with SAPUI5 Adaptation Projects, the variant artifacts (changes, fragments, i18n files, etc.) are stored in the LREP table `/UIF/LREPDCONT`. This report extracts all artifacts belonging to a specific App Variant and saves them to a local folder, preserving the original namespace-based directory structure.
## Prerequisites
- SAP GUI access with authorization to read from `/UIF/LREPDCONT`
- The UI5 App Index must be available (`/UI5/IF_UI5_APP_INDEX_SEARCH`)
- Frontend services must be enabled (file download to the local machine)
## Usage
1. Run the report via transaction `SA38` or `SE38`.
2. Enter the **Custom App ID** (the app variant ID) in the selection screen, or use the **F4 help** to browse all available app variants on the `CUSTOMER_BASE` layer. You can find the App ID via App Support in Launchpad.
3. If the variant is linked to multiple standard apps, a popup lets you pick the correct one.
4. Select a **download folder** on your local machine.
5. The report downloads all artifacts and displays a count of saved files.
## How It Works
| Step | Description |
|------|-------------|
| **Resolve Standard App** | Queries `/UIF/LREPDCONT` for distinct namespaces matching the given custom app ID and extracts the standard app name from the namespace path (`apps/<std_app>/appVariants/<custom_app>`). |
| **Fetch Documents** | Selects all records (namespace, name, type, binary content) from the `CUSTOMER_BASE` layer for the resolved app variant path. |
| **Download** | Converts each `XSTRING` content to binary, creates the necessary sub-folders on the local file system, and saves each file as `<name>.<type>`. |
## Selection Screen
| Parameter | Description |
|-----------|-------------|
| `P_CUST`  | Custom App ID (app variant identifier). Mandatory, lowercase. F4 help available. |
## Key Components
- **`LCL_ADAPTATION_DOWNLOADER`** -- Local class containing all download logic.
- **`/UIF/LREPDCONT`** -- SAP LREP content table (source of the artifacts).
- **`/UI5/CL_UI5_APP_API_FACTORY`** -- Factory used by the F4 help to query the UI5 App Index.
