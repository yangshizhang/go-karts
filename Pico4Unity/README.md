# GoKarts Pico 4 Unity Port

This folder is the Pico 4 port of the iOS MR racing-line prototype. Pico 4 targets Android XR, so the iOS SwiftUI/ARKit app cannot be compiled directly for Pico. The port uses Unity + OpenXR + PICO Unity Integration.

## Recommended Stack

- Unity `2022.3 LTS`.
- Android Build Support, Android SDK/NDK, and OpenJDK from Unity Hub.
- PICO Unity Integration SDK from the official PICO developer resources page.
- Unity XR Plug-in Management + OpenXR.
- PICO OpenXR feature group / PICO loader after importing PICO SDK.

Official docs reviewed:

- PICO SDK resources: https://developer-cn.picoxr.com/resources/#sdk
- PICO documentation resources: https://developer-cn.picoxr.com/resources/#document
- Video seethrough / MR: https://developer-cn.picoxr.com/document/unity/seethrough/
- Controller and HMD input mapping: https://developer-cn.picoxr.com/document/unity/input-mapping/
- Interaction overview: https://developer-cn.picoxr.com/document/unity/interaction/
- XR devices: https://developer-cn.picoxr.com/document/discover/xr-devices/

## What Has Been Ported

- `PicoTrackModels.cs`: serializable track, lap mode, racing-line point, and speed signal models.
- `PicoTrackStore.cs`: persistent track save/load using `Application.persistentDataPath/tracks.json`.
- `PicoRacingLineRenderer.cs`: converts GPS coordinates into local Unity meter coordinates and renders 3D racing-line segments on the ground.
- `PicoTrackInputController.cs`: controller actions for selecting tracks and recentering the racing-line root.
- `PicoTrackJsonImporter.cs`: imports saved track JSON into the Pico app.

## Scene Setup

1. Open `Pico4Unity` with Unity `2022.3 LTS`.
2. Import PICO Unity Integration SDK.
3. Open Project Settings → XR Plug-in Management:
   - Enable Android provider for PICO/OpenXR according to the imported SDK documentation.
   - Enable PICO/OpenXR features required by your SDK version.
4. Switch platform to Android.
5. Create a scene with:
   - XR Origin / camera rig from PICO or OpenXR samples.
   - Empty GameObject `TrackStore` with `PicoTrackStore`.
   - Empty GameObject `RacingLineRoot` with `PicoRacingLineRenderer`.
   - Optional GameObject with `PicoTrackInputController`.
6. Assign references in Inspector:
   - `PicoRacingLineRenderer.trackStore` → `TrackStore`.
   - `PicoRacingLineRenderer.xrOrigin` → XR Origin or Main Camera transform.
   - `PicoTrackInputController.lineRoot` → `RacingLineRoot`.
   - `PicoTrackInputController.headTransform` → Main Camera.
7. If using video see-through, enable it following PICO's seethrough document and set the camera clear/background behavior accordingly.

## Track Data Migration

The iOS app saves tracks with the same conceptual fields: name, lap mode, boundary, and racing line GPS points. For Pico, provide a JSON in this shape:

```json
{
  "tracks": [
    {
      "id": "track-id",
      "name": "赛道名",
      "lapMode": 1,
      "boundary": [],
      "racingLine": [
        {
          "latitude": 31.0,
          "longitude": 121.0,
          "altitude": 0.0,
          "speed": 8.5,
          "unixMilliseconds": 1760000000000,
          "signal": 0
        }
      ],
      "updatedUnixMilliseconds": 1760000000000
    }
  ]
}
```

`lapMode`: `0` = point-to-point, `1` = closed circuit.  
`signal`: `0` = accelerate, `1` = braking.

## MR Alignment Notes

This port renders the saved GPS racing line in Unity world space by taking the first racing-line point as the local origin. For real-world track alignment on Pico 4, you still need a calibration step because consumer GPS and head-mounted inside-out tracking do not share a global coordinate frame.

Recommended calibration workflow:

1. User stands on the saved start point.
2. User faces the real track forward direction.
3. Press recenter action.
4. `RacingLineRoot` is placed two meters in front of the HMD and aligned with the user's facing direction.
5. Optional: add manual left/right/forward/yaw nudges via controller thumbsticks.

This gives stable local MR placement after initial alignment. For higher precision, add physical markers, visual anchors, or a known survey point on the track.

## Build

1. Connect Pico 4 by USB and enable developer mode.
2. Unity → Build Settings → Android → Build or Build And Run.
3. If using command line, configure Unity batch mode with Android target and your installed PICO SDK.
