---
title: OpenAI image URLs expire and break locally saved projects
date: 2026-04-10
category: integration-issues
module: OpenAIService
problem_type: integration_issue
component: service_object
symptoms:
  - Generated images become unavailable after ~60 minutes
  - Saved project files contain stale URLs instead of image data
  - Reopening a project shows broken/missing frame images
root_cause: wrong_api
resolution_type: code_fix
severity: high
tags:
  - openai
  - image-generation
  - b64-json
  - local-persistence
  - expiring-urls
---

# OpenAI image URLs expire and break locally saved projects

## Problem

OpenAI's image generation API returns temporary URLs by default. These URLs expire after approximately 60 minutes. Any app that saves projects to disk and references these URLs will silently lose image data when the user reopens the project later.

## Symptoms

- Generated images render correctly during the session but fail to load after restarting the app
- Project files contain `https://oaidalleapiprodscus.blob.core.windows.net/...` URLs that return 403/404
- No error at generation time — the failure is deferred to the next session

## What Didn't Work

- **Downloading from URL immediately after generation**: Adds a second network round-trip and a race condition — if the download fails or the app crashes before completing, the image is lost. Also adds complexity managing a temporary URL-to-Data pipeline.

## Solution

Request `response_format: "b64_json"` in the image generation API call. The response returns base64-encoded image data inline, which can be decoded and persisted immediately without any dependency on temporary URLs.

**Before** (URL-based with fallback):
```swift
let body: [String: Any] = [
    "model": model,
    "prompt": prompt,
    "n": 1,
    "size": size,
]

// Response handling required two code paths
if let b64 = first["b64_json"] as? String,
   let imageData = Data(base64Encoded: b64) {
    return imageData
}
if let urlString = first["url"] as? String,
   let url = URL(string: urlString) {
    let (imageData, _) = try await URLSession.shared.data(from: url)
    return imageData
}
```

**After** (b64_json only):
```swift
let body: [String: Any] = [
    "model": model,
    "prompt": prompt,
    "n": 1,
    "size": size,
    "response_format": "b64_json",
]

guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let dataArray = json["data"] as? [[String: Any]],
      let first = dataArray.first,
      let b64 = first["b64_json"] as? String,
      let imageData = Data(base64Encoded: b64)
else {
    throw ServiceError.imageGenerationFailed("No image data in response")
}
return imageData
```

## Why This Works

OpenAI's image API supports two response formats: `url` (default) and `b64_json`. The URL format is convenient for ephemeral use (web apps that display images immediately) but hostile to local persistence. The `b64_json` format returns the full image payload in the response body, eliminating the time-sensitivity entirely. The image data is available for immediate persistence without any additional network calls.

## Prevention

- Default to `b64_json` in any application that persists generated images to disk or database
- If using `url` format for bandwidth reasons (e.g., server-side proxy that doesn't store images), document the expiration window and ensure downstream consumers handle 403/404 gracefully
- Add a unit test that asserts the request body includes `"response_format": "b64_json"` to prevent regression

## Related Issues

- Discovered during code review of Keyframe integration wiring (Units 9-16)
- Documented in plan: `docs/plans/2026-04-10-003-fix-review-findings-plan.md`, Unit 19
