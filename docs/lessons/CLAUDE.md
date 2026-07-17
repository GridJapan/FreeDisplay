# Pitfalls Index — FreeDisplay

> Updated: 2026-03-05

## Topic Index

| Topic | File | Entries |
|------|------|------|
| IOKit / DDC / rotation / ambient light / display matching / Apple Silicon | [iokit.md](iokit.md) | L-003, L-004, L-005 + general entries |
| CoreGraphics / HiDPI / CGVirtualDisplay | [coregraphics.md](coregraphics.md) | L-006, L-007, L-020 ~ L-027 + general entries |
| SwiftUI / MenuBarExtra / UI animation / DDC caching / performance | [swiftui.md](swiftui.md) | general entries |
| Cross-Service coordination / concurrency / resource management | [services.md](services.md) | L-008 ~ L-019 |
| Xcode build / Phase wrap-up | [build.md](build.md) | general entries |

## Permanent Rules (Frequent Pitfalls)

1. **After adding a Swift source file you must run `xcodegen generate`** — otherwise the compiler does not know about the new file ("cannot find in scope")
2. **Two Services must not each write the same CoreGraphics resource** — designate a single writer; the others influence it through an interface (see services.md L-008)
3. **Always pass self to C callbacks with `Unmanaged.passRetained`, with a paired release on unregister** — passUnretained is a dangling-pointer time bomb
4. **❌ CGConfigureDisplayMirrorOfDisplay for HiDPI** — on Apple Silicon it triggers hardware mirroring + mouse stutter, ✅ use a plist override (/Library/Displays/)
